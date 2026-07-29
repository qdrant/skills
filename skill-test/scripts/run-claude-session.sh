#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="${CLAUDE_TEST_IMAGE:-claude-code-skill-test:latest}"
ENV_FILE=""
if [[ -f "$REPO_ROOT/.env" ]]; then
  ENV_FILE="$REPO_ROOT/.env"
fi

PROMPT_FILE=""
SKILLS_DIR=""
PLUGIN_DIR=""
WORKSPACE_DIR=""
WORKSPACE_MODE="ro"
PERMISSION_MODE="auto"
MODEL=""
CLAUDE_EXTRA_ARGS="${CLAUDE_EXTRA_ARGS:-}"
ALLOW_MISSING_AUTH="0"
PLUGIN_URLS=()

usage() {
  cat <<'USAGE'
Usage: scripts/run-claude-session.sh [options] [PROMPT_FILE]

Starts an interactive Claude Code session inside a fresh disposable Docker
container. Use this when you want to ask follow-up questions in the same test
session. When you exit Claude, the container is removed.

Options:
  --image NAME                 Docker image tag to run.
  --env-file FILE              Docker env-file with credentials. Defaults to .env if present.
  --no-env-file                Do not pass an env-file.
  --skills-dir DIR             Mount a local Claude skill or directory of skills.
  --plugin-dir DIR             Mount a local Claude Code plugin directory.
  --plugin-url URL             Load a plugin zip URL for this session. Repeatable.
  --workspace DIR              Mount a host workspace read-only at /workspace.
  --workspace-rw               Make --workspace read-write.
  --permission-mode MODE       default, acceptEdits, plan, auto, dontAsk, or bypassPermissions.
                               Default: auto.
  --model MODEL                Pass --model to Claude Code.
  --extra-args "ARGS"          Advanced Claude Code flags passed through by the container.
  --allow-missing-auth         Skip local auth preflight checks.
  -h, --help                   Show this help.

Auth:
  Put ANTHROPIC_API_KEY=... in .env, pass --env-file, or export it in your shell.
USAGE
}

abs_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$(pwd)" "$path"
  fi
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "Missing value for $option" >&2
    exit 64
  fi
}

VALID_PERMISSION_MODES=(default manual acceptEdits plan auto dontAsk bypassPermissions)

validate_permission_mode() {
  local mode="$1"
  local valid
  for valid in "${VALID_PERMISSION_MODES[@]}"; do
    if [[ "$mode" == "$valid" ]]; then
      return 0
    fi
  done
  echo "Invalid --permission-mode: '$mode'" >&2
  echo "Valid modes: ${VALID_PERMISSION_MODES[*]}" >&2
  echo "See https://code.claude.com/docs/en/permission-modes" >&2
  exit 64
}

env_file_has_value() {
  local file="$1"
  local name="$2"

  [[ -f "$file" ]] || return 1
  grep -Eq "^[[:space:]]*${name}[[:space:]]*=[[:space:]]*['\"]?[^'\"#[:space:]]" "$file"
}

auth_value_set() {
  local name="$1"

  if [[ -n "${!name:-}" ]]; then
    return 0
  fi

  if [[ -n "$ENV_FILE" ]]; then
    env_file_has_value "$(abs_path "$ENV_FILE")" "$name"
    return $?
  fi

  return 1
}

auth_configured() {
  if auth_value_set ANTHROPIC_API_KEY || auth_value_set ANTHROPIC_AUTH_TOKEN; then
    return 0
  fi

  if auth_value_set CLAUDE_CODE_USE_BEDROCK && auth_value_set AWS_ACCESS_KEY_ID; then
    return 0
  fi

  if auth_value_set CLAUDE_CODE_USE_VERTEX && auth_value_set ANTHROPIC_VERTEX_PROJECT_ID; then
    return 0
  fi

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      require_value "$1" "${2:-}"
      IMAGE="$2"
      shift 2
      ;;
    --env-file)
      require_value "$1" "${2:-}"
      ENV_FILE="$2"
      shift 2
      ;;
    --no-env-file)
      ENV_FILE=""
      shift
      ;;
    --skills-dir)
      require_value "$1" "${2:-}"
      SKILLS_DIR="$2"
      shift 2
      ;;
    --plugin-dir)
      require_value "$1" "${2:-}"
      PLUGIN_DIR="$2"
      shift 2
      ;;
    --plugin-url)
      require_value "$1" "${2:-}"
      PLUGIN_URLS+=("$2")
      shift 2
      ;;
    --workspace)
      require_value "$1" "${2:-}"
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    --workspace-rw)
      WORKSPACE_MODE="rw"
      shift
      ;;
    --permission-mode)
      require_value "$1" "${2:-}"
      PERMISSION_MODE="$2"
      shift 2
      ;;
    --model)
      require_value "$1" "${2:-}"
      MODEL="$2"
      shift 2
      ;;
    --extra-args)
      require_value "$1" "${2:-}"
      CLAUDE_EXTRA_ARGS="$2"
      shift 2
      ;;
    --allow-missing-auth)
      ALLOW_MISSING_AUTH="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
    *)
      if [[ -n "$PROMPT_FILE" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage >&2
        exit 64
      fi
      PROMPT_FILE="$1"
      shift
      ;;
  esac
done

validate_permission_mode "$PERMISSION_MODE"

if [[ -n "$ENV_FILE" ]]; then
  ENV_PATH="$(abs_path "$ENV_FILE")"
  if [[ ! -f "$ENV_PATH" ]]; then
    echo "Env file not found: $ENV_PATH" >&2
    exit 66
  fi
fi

if [[ "$ALLOW_MISSING_AUTH" != "1" ]] && ! auth_configured; then
  cat >&2 <<'AUTH_ERROR'
No Claude Code auth was found.

Set ANTHROPIC_API_KEY in .env, pass --env-file with a non-empty key, or export
ANTHROPIC_API_KEY in your shell before running this script.

For Bedrock or Vertex, set the matching Claude Code mode variables as well.
Use --allow-missing-auth to skip this preflight if you intentionally want Claude
Code to fail or authenticate some other way inside the container.
AUTH_ERROR
  exit 78
fi

docker_args=(
  run
  --rm
  -it
  -e "CLAUDE_WORKSPACE=/workspace"
  -e "CLAUDE_PERMISSION_MODE=$PERMISSION_MODE"
  -e "CLAUDE_MODEL=$MODEL"
  -e "CLAUDE_EXTRA_ARGS=$CLAUDE_EXTRA_ARGS"
  -e ANTHROPIC_API_KEY
  -e ANTHROPIC_AUTH_TOKEN
  -e ANTHROPIC_BASE_URL
  -e ANTHROPIC_MODEL
  -e ANTHROPIC_BETAS
  -e ANTHROPIC_CUSTOM_HEADERS
  -e CLAUDE_CODE_USE_BEDROCK
  -e CLAUDE_CODE_USE_VERTEX
  -e AWS_ACCESS_KEY_ID
  -e AWS_SECRET_ACCESS_KEY
  -e AWS_SESSION_TOKEN
  -e AWS_REGION
  -e ANTHROPIC_VERTEX_PROJECT_ID
  -e GOOGLE_APPLICATION_CREDENTIALS
)

if [[ -n "$ENV_FILE" ]]; then
  docker_args+=(--env-file "$ENV_PATH")
fi

if [[ -n "$PROMPT_FILE" ]]; then
  PROMPT_PATH="$(abs_path "$PROMPT_FILE")"
  if [[ ! -f "$PROMPT_PATH" ]]; then
    echo "Prompt file not found: $PROMPT_PATH" >&2
    exit 66
  fi
  docker_args+=(-e "PROMPT_FILE=/prompt.md" -v "$PROMPT_PATH:/prompt.md:ro")
fi

if [[ -n "$SKILLS_DIR" ]]; then
  SKILLS_PATH="$(abs_path "$SKILLS_DIR")"
  if [[ ! -d "$SKILLS_PATH" ]]; then
    echo "Skills directory not found: $SKILLS_PATH" >&2
    exit 66
  fi
  docker_args+=(-v "$SKILLS_PATH:/input-skills:ro")
fi

if [[ -n "$PLUGIN_DIR" ]]; then
  PLUGIN_PATH="$(abs_path "$PLUGIN_DIR")"
  if [[ ! -d "$PLUGIN_PATH" ]]; then
    echo "Plugin directory not found: $PLUGIN_PATH" >&2
    exit 66
  fi
  docker_args+=(-v "$PLUGIN_PATH:/input-plugin:ro")
fi

if [[ -n "$WORKSPACE_DIR" ]]; then
  WORKSPACE_PATH="$(abs_path "$WORKSPACE_DIR")"
  if [[ ! -d "$WORKSPACE_PATH" ]]; then
    echo "Workspace directory not found: $WORKSPACE_PATH" >&2
    exit 66
  fi
  docker_args+=(-v "$WORKSPACE_PATH:/workspace:$WORKSPACE_MODE")
fi

if [[ "${#PLUGIN_URLS[@]}" -gt 0 ]]; then
  docker_args+=(-e "CLAUDE_PLUGIN_URLS=$(printf '%s\n' "${PLUGIN_URLS[@]}")")
fi

docker_args+=("$IMAGE" run-claude-session)

docker "${docker_args[@]}"
