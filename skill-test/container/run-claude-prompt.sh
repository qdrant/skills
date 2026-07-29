#!/usr/bin/env bash
set -Eeuo pipefail

PROMPT_FILE="${PROMPT_FILE:-/prompt.md}"
RUNS_DIR="${RUNS_DIR:-/runs}"
CLAUDE_RUN_ID="${CLAUDE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
CLAUDE_WORKSPACE="${CLAUDE_WORKSPACE:-/workspace}"
CLAUDE_OUTPUT_FORMAT="${CLAUDE_OUTPUT_FORMAT:-text}"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-auto}"
CLAUDE_MAX_TURNS="${CLAUDE_MAX_TURNS:-20}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"
CLAUDE_MAX_BUDGET_USD="${CLAUDE_MAX_BUDGET_USD:-}"
CLAUDE_PLUGIN_URLS="${CLAUDE_PLUGIN_URLS:-}"
CLAUDE_EXTRA_ARGS="${CLAUDE_EXTRA_ARGS:-}"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 64
fi

run_dir="$RUNS_DIR/$CLAUDE_RUN_ID"
mkdir -p "$run_dir" "$CLAUDE_WORKSPACE" "$HOME/.claude/skills"

cp "$PROMPT_FILE" "$run_dir/prompt.md"

install_skill_dir() {
  local source_dir="$1"
  local skill_name="$2"

  if [[ -f "$source_dir/SKILL.md" ]]; then
    mkdir -p "$HOME/.claude/skills/$skill_name"
    cp -R "$source_dir/." "$HOME/.claude/skills/$skill_name/"
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

args=(
  -p
  --no-session-persistence
  --output-format "$CLAUDE_OUTPUT_FORMAT"
  --permission-mode "$CLAUDE_PERMISSION_MODE"
)

if [[ "$CLAUDE_OUTPUT_FORMAT" == "stream-json" ]]; then
  args+=(--verbose)
fi

if [[ -n "$CLAUDE_MAX_TURNS" ]]; then
  args+=(--max-turns "$CLAUDE_MAX_TURNS")
fi

if [[ -n "$CLAUDE_MODEL" ]]; then
  args+=(--model "$CLAUDE_MODEL")
fi

if [[ -n "$CLAUDE_MAX_BUDGET_USD" ]]; then
  args+=(--max-budget-usd "$CLAUDE_MAX_BUDGET_USD")
fi

if [[ -d /input-plugin ]]; then
  args+=(--plugin-dir /input-plugin)
fi

if [[ -n "$CLAUDE_PLUGIN_URLS" ]]; then
  while IFS= read -r plugin_url; do
    if [[ -n "$plugin_url" ]]; then
      args+=(--plugin-url "$plugin_url")
    fi
  done <<< "$CLAUDE_PLUGIN_URLS"
fi

if [[ -n "$CLAUDE_EXTRA_ARGS" ]]; then
  # Whitespace tokenization is intentional here so callers can pass advanced
  # Claude Code flags without this wrapper needing to model every one.
  read -r -a extra_args <<< "$CLAUDE_EXTRA_ARGS"
  args+=("${extra_args[@]}")
fi

prompt="$(< "$PROMPT_FILE")"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

set +e
(
  cd "$CLAUDE_WORKSPACE"
  claude "${args[@]}" "$prompt"
) > "$run_dir/stdout.txt" 2> "$run_dir/stderr.txt"
status=$?
set -e

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg run_id "$CLAUDE_RUN_ID" \
  --arg started_at "$started_at" \
  --arg finished_at "$finished_at" \
  --arg output_format "$CLAUDE_OUTPUT_FORMAT" \
  --arg permission_mode "$CLAUDE_PERMISSION_MODE" \
  --arg max_turns "$CLAUDE_MAX_TURNS" \
  --arg model "$CLAUDE_MODEL" \
  --arg max_budget_usd "$CLAUDE_MAX_BUDGET_USD" \
  --argjson exit_code "$status" \
  '{
    run_id: $run_id,
    started_at: $started_at,
    finished_at: $finished_at,
    exit_code: $exit_code,
    output_format: $output_format,
    permission_mode: $permission_mode,
    max_turns: $max_turns,
    model: $model,
    max_budget_usd: $max_budget_usd
  }' > "$run_dir/metadata.json"

echo "Run directory: $run_dir"
echo "Exit code: $status"
exit "$status"
