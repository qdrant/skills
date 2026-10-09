#!/usr/bin/env bash
set -Eeuo pipefail

# Codex CLI counterpart to run-claude-prompt.sh. Mirrors its contract exactly
# (same env var names where the concept is shared, same runs/<id>/ output
# shape) so the host-side harness can treat the two agents interchangeably.
#
# Differences from run-claude-prompt.sh:
#   - Auth: `codex exec` does not read OPENAI_API_KEY/CODEX_API_KEY/
#     CODEX_ACCESS_TOKEN itself. One of them must be handed to `codex login`
#     (via stdin) first, which writes $CODEX_HOME/auth.json; exec then picks
#     that up. A login failure exits immediately (see login-stderr.txt)
#     instead of burning the exec timeout on a run that can only 401.
#   - Skills: confirmed via `codex debug prompt-input` that Codex discovers
#     skills from several roots at once — $CODEX_HOME/skills (global),
#     $CODEX_HOME/skills/.system (bundled), <cwd>/.codex/skills, and
#     <cwd>/.agents/skills. This installs into $CODEX_HOME/skills/<name>/,
#     mirroring run-claude-prompt.sh's $HOME/.claude/skills/<name>/ exactly —
#     NOT under the workspace. A workspace-relative install broke any run with
#     a read-only --workspace mount (the install step's mkdir/cp failed before
#     Codex even started).
#   - Permissions: confirmed empirically, inside this same Docker image, that
#     Codex's own sandbox cannot run here at all — its bwrap backend needs
#     unprivileged Linux user-namespaces that Docker's default seccomp profile
#     blocks. `--sandbox read-only` (mapped from plan/default/manual) hard-fails
#     every shell command with a `bwrap: No permissions...` error surfaced as
#     the model's actual final answer. `--approve-for-me` (mapped from auto/
#     acceptEdits) degrades rather than hard-fails — Codex silently retries
#     each shell command once outside the broken sandbox — but that still
#     means every command runs twice, and approvals route through Codex's own
#     auto-review model, adding cost and nondeterminism to eval runs. Given
#     neither "safe" mode actually constrains anything in this container, every
#     permission mode maps to the same full bypass; the outer disposable
#     Docker container (--rm, no host mount beyond /workspace and /runs) is
#     the real isolation boundary regardless. CODEX_PERMISSION_MODE is still
#     recorded in metadata.json for traceability even though it no longer
#     changes which Codex flag gets used.
#   - No --max-turns / --max-budget-usd equivalent either. A wall-clock
#     `timeout` is the only run-length backstop available.
#   - Output: stdout.txt holds the --json event stream (same idea as Claude's
#     stream-json), and -o/--output-last-message writes the clean final answer
#     straight to final.txt, which scoring can read directly instead of
#     parsing the event stream.

PROMPT_FILE="${PROMPT_FILE:-/prompt.md}"
RUNS_DIR="${RUNS_DIR:-/runs}"
CLAUDE_RUN_ID="${CLAUDE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
CLAUDE_WORKSPACE="${CLAUDE_WORKSPACE:-/workspace}"
CODEX_MODEL="${CODEX_MODEL:-}"
CODEX_PERMISSION_MODE="${CODEX_PERMISSION_MODE:-auto}"
CODEX_EXTRA_ARGS="${CODEX_EXTRA_ARGS:-}"
# Backstop only (exec has no --max-turns/--max-budget-usd equivalent). Empty
# disables it. Default is generous since there's no cheaper per-turn signal
# to cut a run short on.
CODEX_TIMEOUT_SECS="${CODEX_TIMEOUT_SECS:-600}"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 64
fi

# CODEX_HOME defaults to ~/.codex, same default the installed `codex` binary
# itself uses when the env var is unset.
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_DIR="$CODEX_HOME/skills"

run_dir="$RUNS_DIR/$CLAUDE_RUN_ID"
mkdir -p "$run_dir" "$CLAUDE_WORKSPACE" "$CODEX_SKILLS_DIR"

cp "$PROMPT_FILE" "$run_dir/prompt.md"

install_skill_dir() {
  local source_dir="$1"
  local skill_name="$2"

  if [[ -f "$source_dir/SKILL.md" ]]; then
    mkdir -p "$CODEX_SKILLS_DIR/$skill_name"
    cp -R "$source_dir/." "$CODEX_SKILLS_DIR/$skill_name/"
  fi
}

if [[ -d /input-skills ]]; then
  if [[ -f /input-skills/SKILL.md ]]; then
    install_skill_dir /input-skills mounted-skill
  else
    shopt -s nullglob
    for skill_dir in /input-skills/*; do
      if [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]]; then
        install_skill_dir "$skill_dir" "$(basename "$skill_dir")"
      fi
    done
  fi
fi

# All six shared --permission-mode names currently map to the same full
# bypass: confirmed (see the file header) that Codex's own --sandbox/
# --approve-for-me flags cannot meaningfully run inside this container, so
# there is nothing a finer-grained mapping would actually buy. Still validated
# explicitly (rather than skipping straight to the flag) so a mode name that
# isn't one of the six the host validates fails loudly instead of silently
# running unsandboxed. Assigned directly in this top-level case (not inside a
# function called via command substitution) so `exit` here actually exits the
# script instead of just the subshell a `$(...)` capture would create.
case "$CODEX_PERMISSION_MODE" in
  bypassPermissions|dontAsk|auto|acceptEdits|plan|default|manual)
    permission_flags=(--dangerously-bypass-approvals-and-sandbox)
    ;;
  *)
    echo "Unknown permission mode: '$CODEX_PERMISSION_MODE'" >&2
    exit 64
    ;;
esac

login_status="skipped (no credentials)"
api_key="${OPENAI_API_KEY:-${CODEX_API_KEY:-}}"
if [[ -n "$api_key" ]]; then
  if printf '%s' "$api_key" | codex login --with-api-key >/dev/null 2>"$run_dir/login-stderr.txt"; then
    login_status="ok"
  else
    login_status="failed"
  fi
elif [[ -n "${CODEX_ACCESS_TOKEN:-}" ]]; then
  if printf '%s' "$CODEX_ACCESS_TOKEN" | codex login --with-access-token >/dev/null 2>"$run_dir/login-stderr.txt"; then
    login_status="ok"
  else
    login_status="failed"
  fi
fi

if [[ "$login_status" == "failed" ]]; then
  echo "codex login failed; see $run_dir/login-stderr.txt" >&2
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg agent "codex" \
    --arg run_id "$CLAUDE_RUN_ID" \
    --arg finished_at "$finished_at" \
    --arg login_status "$login_status" \
    '{agent: $agent, run_id: $run_id, finished_at: $finished_at, login_status: $login_status, exit_code: 78}' \
    > "$run_dir/metadata.json"
  exit 78
fi

args=(
  exec
  --json
  --skip-git-repo-check
  "${permission_flags[@]}"
  -o "$run_dir/final.txt"
)

if [[ -n "$CODEX_MODEL" ]]; then
  args+=(-m "$CODEX_MODEL")
fi

if [[ -n "$CODEX_EXTRA_ARGS" ]]; then
  # Whitespace tokenization is intentional here, matching run-claude-prompt.sh's
  # CLAUDE_EXTRA_ARGS: callers can pass advanced Codex flags without this
  # wrapper needing to model every one.
  read -r -a extra_args <<< "$CODEX_EXTRA_ARGS"
  args+=("${extra_args[@]}")
fi

prompt="$(< "$PROMPT_FILE")"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

set +e
(
  cd "$CLAUDE_WORKSPACE"
  if [[ -n "$CODEX_TIMEOUT_SECS" ]]; then
    timeout "${CODEX_TIMEOUT_SECS}s" codex "${args[@]}" "$prompt"
  else
    codex "${args[@]}" "$prompt"
  fi
) > "$run_dir/stdout.txt" 2> "$run_dir/stderr.txt"
status=$?
set -e

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
timed_out=0
[[ -n "$CODEX_TIMEOUT_SECS" && "$status" -eq 124 ]] && timed_out=1

jq -n \
  --arg agent "codex" \
  --arg run_id "$CLAUDE_RUN_ID" \
  --arg started_at "$started_at" \
  --arg finished_at "$finished_at" \
  --arg model "$CODEX_MODEL" \
  --arg permission_mode "$CODEX_PERMISSION_MODE" \
  --arg login_status "$login_status" \
  --arg timeout_secs "$CODEX_TIMEOUT_SECS" \
  --argjson exit_code "$status" \
  --argjson timed_out "$timed_out" \
  '{
    agent: $agent,
    run_id: $run_id,
    started_at: $started_at,
    finished_at: $finished_at,
    exit_code: $exit_code,
    model: $model,
    permission_mode: $permission_mode,
    login_status: $login_status,
    timeout_secs: $timeout_secs,
    timed_out: $timed_out
  }' > "$run_dir/metadata.json"

echo "Run directory: $run_dir"
echo "Exit code: $status"
exit "$status"
