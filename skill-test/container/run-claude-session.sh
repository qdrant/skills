#!/usr/bin/env bash
set -Eeuo pipefail

PROMPT_FILE="${PROMPT_FILE:-}"
CLAUDE_WORKSPACE="${CLAUDE_WORKSPACE:-/workspace}"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-auto}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"
CLAUDE_PLUGIN_URLS="${CLAUDE_PLUGIN_URLS:-}"
CLAUDE_EXTRA_ARGS="${CLAUDE_EXTRA_ARGS:-}"

mkdir -p "$CLAUDE_WORKSPACE" "$HOME/.claude/skills"

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

args=(--permission-mode "$CLAUDE_PERMISSION_MODE")

if [[ -n "$CLAUDE_MODEL" ]]; then
  args+=(--model "$CLAUDE_MODEL")
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
  read -r -a extra_args <<< "$CLAUDE_EXTRA_ARGS"
  args+=("${extra_args[@]}")
fi

if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
  args+=("$(< "$PROMPT_FILE")")
fi

cd "$CLAUDE_WORKSPACE"
exec claude "${args[@]}"
