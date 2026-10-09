#!/usr/bin/env bash
set -Eeuo pipefail

# Codex CLI counterpart to run-claude-prompt.sh. Mirrors its contract exactly
# (same env var names where the concept is shared, same runs/<id>/ output
# shape) so the host-side harness can treat the two agents interchangeably.
#
# Differences from run-claude-prompt.sh, learned from the Phase 0 spike:
#   - Auth: `codex exec` does not read OPENAI_API_KEY itself. It must be
#     handed to `codex login --with-api-key` (via stdin) first, which writes
#     $CODEX_HOME/auth.json; exec then picks that up.
#   - Skills: Codex has no ~/.claude/skills-style global install step used by
#     the model automatically here. Skills are discovered from
#     <cwd>/.codex/skills/<name>/SKILL.md, resolved relative to the process's
#     cwd — so they're installed under the workspace, not $HOME.
#   - No single --permission-mode on `codex exec`; it has two independent
#     flags instead (--sandbox and --approve-for-me / the full-bypass flag).
#     CODEX_PERMISSION_MODE maps the harness's six permission-mode names onto
#     them (see map_permission_mode below) — run-claude-test.sh's --help has
#     the full table. The outer Docker container (--rm, no host mount beyond
#     /workspace and /runs) is already the real isolation boundary, which is
#     why even the "safe" modes don't bother fighting Codex's internal bwrap
#     sandbox (it needs Linux user-namespaces the container may not grant) —
#     they just restrict the sandbox/approval flags Codex itself exposes.
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

run_dir="$RUNS_DIR/$CLAUDE_RUN_ID"
mkdir -p "$run_dir" "$CLAUDE_WORKSPACE" "$CLAUDE_WORKSPACE/.codex/skills"

cp "$PROMPT_FILE" "$run_dir/prompt.md"

install_skill_dir() {
  local source_dir="$1"
  local skill_name="$2"

  if [[ -f "$source_dir/SKILL.md" ]]; then
    mkdir -p "$CLAUDE_WORKSPACE/.codex/skills/$skill_name"
    cp -R "$source_dir/." "$CLAUDE_WORKSPACE/.codex/skills/$skill_name/"
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

# Translates the harness's six shared --permission-mode names onto Codex's own
# --sandbox / --approve-for-me / full-bypass flags. --sandbox and
# --approve-for-me are mutually exclusive on `codex exec`, so each mode picks
# exactly one path. See the Dockerfile-era comment above for why bypass is a
# reasonable default even for the "safe" modes.
map_permission_mode() {
  case "$1" in
    bypassPermissions|dontAsk)
      echo "--dangerously-bypass-approvals-and-sandbox"
      ;;
    auto|acceptEdits)
      echo "--approve-for-me"
      ;;
    plan|default|manual)
      echo "--sandbox read-only"
      ;;
    *)
      echo "--dangerously-bypass-approvals-and-sandbox"
      ;;
  esac
}

login_status="skipped (no API key)"
api_key="${OPENAI_API_KEY:-${CODEX_API_KEY:-}}"
if [[ -n "$api_key" ]]; then
  if printf '%s' "$api_key" | codex login --with-api-key >/dev/null 2>"$run_dir/login-stderr.txt"; then
    login_status="ok"
  else
    login_status="failed"
  fi
fi

permission_flags=($(map_permission_mode "$CODEX_PERMISSION_MODE"))

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
