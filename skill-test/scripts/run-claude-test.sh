#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="${CLAUDE_TEST_IMAGE:-claude-code-skill-test:latest}"
RUNS_DIR="${CLAUDE_TEST_RUNS_DIR:-runs}"
ENV_FILE=""
if [[ -f "$REPO_ROOT/.env" ]]; then
  ENV_FILE="$REPO_ROOT/.env"
fi

PROMPT_FILE=""
SKILLS_DIR=""
PLUGIN_DIR=""
WORKSPACE_DIR=""
WORKSPACE_MODE="ro"
OUTPUT_FORMAT="stream-json"
PERMISSION_MODE="auto"
MAX_TURNS="20"
MODEL=""
MAX_BUDGET_USD=""
BUILD_IMAGE="0"
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-latest}"
CLAUDE_EXTRA_ARGS="${CLAUDE_EXTRA_ARGS:-}"
ALLOW_MISSING_AUTH="0"
RENDER_TRANSCRIPT="1"
PLUGIN_URLS=()

usage() {
  cat <<'USAGE'
Usage: scripts/run-claude-test.sh [options] PROMPT_FILE

Runs a fresh Docker container with Claude Code, sends PROMPT_FILE to `claude -p`,
and stores stdout, stderr, the prompt, and metadata under runs/<run-id>/.

PROMPT_FILE may be a plain prompt file (its whole contents are the prompt) or a
JSON test-prompt with a "prompt" field (that field is extracted and used, and the
JSON is copied to runs/<run-id>/test-prompt.json for scoring).

Options:
  --build                      Build the Docker image before running.
  --image NAME                 Docker image tag to run.
  --claude-code-version VER    Claude Code version to use when --build is set.
  --runs-dir DIR               Host directory for captured runs.
  --env-file FILE              Docker env-file with credentials. Defaults to .env if present.
  --no-env-file                Do not pass an env-file.
  --skills-dir DIR             Mount a local Claude skill or directory of skills.
  --plugin-dir DIR             Mount a local Claude Code plugin directory.
  --plugin-url URL             Load a plugin zip URL for this run. Repeatable.
  --workspace DIR              Mount a host workspace read-only at /workspace.
  --workspace-rw               Make --workspace read-write.
  --output-format FORMAT       text, json, or stream-json. Default: stream-json.
  --permission-mode MODE       default, acceptEdits, plan, auto, dontAsk, or bypassPermissions.
                               Default: auto.
  --max-turns N                Claude Code print-mode max turns. Default: 20.
  --model MODEL                Pass --model to Claude Code.
  --choose-model               Interactively choose a model from a menu.
  --max-budget-usd USD         Stop once this print-mode budget is reached.
  --extra-args "ARGS"          Advanced Claude Code flags passed through by the container.
  --allow-missing-auth         Skip local auth preflight checks.
  --no-render                  Do not generate readable.md after the run.
  -h, --help                   Show this help.

Auth:
  Put ANTHROPIC_API_KEY=... in .env, pass --env-file, or export it in your shell.
  The runner also forwards common Anthropic/Bedrock/Vertex env vars by name.
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

choose_model() {
  local model
  PS3="Select a Claude model: "
  select model in "haiku" "sonnet" "opus"; do
    if [[ -n "$model" ]]; then
      echo "$model"
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      BUILD_IMAGE="1"
      shift
      ;;
    --image)
      require_value "$1" "${2:-}"
      IMAGE="$2"
      shift 2
      ;;
    --claude-code-version)
      require_value "$1" "${2:-}"
      CLAUDE_CODE_VERSION="$2"
      shift 2
      ;;
    --runs-dir)
      require_value "$1" "${2:-}"
      RUNS_DIR="$2"
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
    --output-format)
      require_value "$1" "${2:-}"
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --permission-mode)
      require_value "$1" "${2:-}"
      PERMISSION_MODE="$2"
      shift 2
      ;;
    --max-turns)
      require_value "$1" "${2:-}"
      MAX_TURNS="$2"
      shift 2
      ;;
    --model)
      require_value "$1" "${2:-}"
      MODEL="$2"
      shift 2
      ;;
    --choose-model)
      MODEL="$(choose_model)" || exit 1
      shift
      ;;
    --max-budget-usd)
      require_value "$1" "${2:-}"
      MAX_BUDGET_USD="$2"
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
    --no-render)
      RENDER_TRANSCRIPT="0"
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

if [[ -z "$PROMPT_FILE" ]]; then
  echo "Missing PROMPT_FILE" >&2
  usage >&2
  exit 64
fi

validate_permission_mode "$PERMISSION_MODE"

PROMPT_PATH="$(abs_path "$PROMPT_FILE")"
RUNS_PATH="$(abs_path "$RUNS_DIR")"

if [[ ! -f "$PROMPT_PATH" ]]; then
  echo "Prompt file not found: $PROMPT_PATH" >&2
  exit 66
fi

# Track the original input separately from the prompt actually mounted into the
# container. For a JSON test-prompt we extract its .prompt field into a temp
# Markdown file and mount that, while keeping the JSON for naming and metadata.
PROMPT_SOURCE_PATH="$PROMPT_PATH"
TEST_PROMPT_JSON=""
if [[ "$PROMPT_PATH" == *.json ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to use a JSON test-prompt: $PROMPT_PATH" >&2
    exit 69
  fi
  if ! jq -e . "$PROMPT_PATH" >/dev/null 2>&1; then
    echo "Invalid JSON test-prompt: $PROMPT_PATH" >&2
    exit 65
  fi
  if ! jq -e '(.prompt | type == "string") and (.prompt | length > 0)' \
      "$PROMPT_PATH" >/dev/null 2>&1; then
    echo "JSON test-prompt needs a non-empty string \"prompt\" field: $PROMPT_PATH" >&2
    exit 65
  fi
  TEST_PROMPT_JSON="$PROMPT_PATH"
  EXTRACTED_PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/claude-test-prompt.XXXXXX")"
  trap 'rm -f "$EXTRACTED_PROMPT_FILE"' EXIT
  jq -r '.prompt' "$PROMPT_PATH" > "$EXTRACTED_PROMPT_FILE"
  PROMPT_PATH="$EXTRACTED_PROMPT_FILE"
fi

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

mkdir -p "$RUNS_PATH"

if [[ "$BUILD_IMAGE" == "1" ]]; then
  "$SCRIPT_DIR/build-image.sh" \
    --image "$IMAGE" \
    --claude-code-version "$CLAUDE_CODE_VERSION"
fi

if [[ -n "$TEST_PROMPT_JSON" ]]; then
  # Prefer the test-prompt's canonical .name over the file name so the run id
  # tracks the test even if the file is renamed. Fall back to the file name if
  # .name is missing or empty.
  prompt_base="$(jq -r 'if (.name | type == "string") and (.name | length > 0) then .name else empty end' "$TEST_PROMPT_JSON")"
  if [[ -z "$prompt_base" ]]; then
    prompt_base="$(basename "$PROMPT_SOURCE_PATH")"
    prompt_base="${prompt_base%.*}"
  fi
else
  prompt_base="$(basename "$PROMPT_SOURCE_PATH")"
  prompt_base="${prompt_base%.*}"
fi
prompt_slug="$(printf '%s' "$prompt_base" | tr -c 'A-Za-z0-9._-' '_')"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$prompt_slug"

plugin_urls_joined=""
if [[ "${#PLUGIN_URLS[@]}" -gt 0 ]]; then
  plugin_urls_joined="$(printf '%s\n' "${PLUGIN_URLS[@]}")"
fi

docker_args=(
  run
  --rm
  --name "$run_id"
  -e "PROMPT_FILE=/prompt.md"
  -e "RUNS_DIR=/runs"
  -e "CLAUDE_RUN_ID=$run_id"
  -e "CLAUDE_WORKSPACE=/workspace"
  -e "CLAUDE_OUTPUT_FORMAT=$OUTPUT_FORMAT"
  -e "CLAUDE_PERMISSION_MODE=$PERMISSION_MODE"
  -e "CLAUDE_MAX_TURNS=$MAX_TURNS"
  -e "CLAUDE_MODEL=$MODEL"
  -e "CLAUDE_MAX_BUDGET_USD=$MAX_BUDGET_USD"
  -e "CLAUDE_PLUGIN_URLS=$plugin_urls_joined"
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
  -v "$PROMPT_PATH:/prompt.md:ro"
  -v "$RUNS_PATH:/runs"
)

if [[ -n "$ENV_FILE" ]]; then
  docker_args+=(--env-file "$ENV_PATH")
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

docker_args+=("$IMAGE" run-claude-prompt)

echo "Starting Claude Code test: $run_id"
echo "Capturing output under: $RUNS_PATH/$run_id"

set +e
docker "${docker_args[@]}"
docker_status=$?
set -e

run_dir="$RUNS_PATH/$run_id"
if [[ -n "$TEST_PROMPT_JSON" && -d "$run_dir" ]]; then
  cp "$TEST_PROMPT_JSON" "$run_dir/test-prompt.json"
fi

if [[ "$RENDER_TRANSCRIPT" == "1" && -f "$run_dir/stdout.txt" ]]; then
  transcript_path="$run_dir/readable.md"
  if "$SCRIPT_DIR/render-claude-stdout.js" "$run_dir" --output "$transcript_path"; then
    echo "Readable transcript: $transcript_path"
  else
    echo "Warning: failed to render readable transcript for $run_dir" >&2
  fi
fi

exit "$docker_status"
