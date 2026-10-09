#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="${CLAUDE_TEST_IMAGE:-claude-code-skill-test:latest}"
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-latest}"
# Pinned, not latest: the Codex CLI's flags were observed to change between
# patch releases during harness development. See the Dockerfile's CODEX_VERSION
# comment.
CODEX_VERSION="${CODEX_VERSION:-0.160.1}"
NODE_IMAGE="${CLAUDE_TEST_NODE_IMAGE:-node:22-bookworm-slim}"
BUILD_ATTEMPTS="${CLAUDE_TEST_BUILD_ATTEMPTS:-3}"
PULL_BASE="0"

usage() {
  cat <<'USAGE'
Usage: scripts/build-image.sh [options]

Options:
  --image NAME                 Docker image tag to build.
  --claude-code-version VER    Claude Code npm package version or "latest".
  --codex-version VER          Codex CLI npm package version or "latest".
                               Default: 0.160.1 (pinned; see Dockerfile).
  --node-image IMAGE           Base Node image. Default: node:22-bookworm-slim.
  --attempts N                 Retry docker build up to N times. Default: 3.
  --pull                       Always attempt to pull a newer base image.
  -h, --help                   Show this help.

Environment:
  CLAUDE_TEST_IMAGE            Default image tag.
  CLAUDE_CODE_VERSION          Default Claude Code package version.
  CODEX_VERSION                Default Codex CLI package version.
  CLAUDE_TEST_NODE_IMAGE       Default base Node image.
  CLAUDE_TEST_BUILD_ATTEMPTS   Default retry count.
USAGE
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "Missing value for $option" >&2
    exit 64
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --codex-version)
      require_value "$1" "${2:-}"
      CODEX_VERSION="$2"
      shift 2
      ;;
    --node-image)
      require_value "$1" "${2:-}"
      NODE_IMAGE="$2"
      shift 2
      ;;
    --attempts)
      require_value "$1" "${2:-}"
      BUILD_ATTEMPTS="$2"
      shift 2
      ;;
    --pull)
      PULL_BASE="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if ! [[ "$BUILD_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "--attempts must be a positive integer" >&2
  exit 64
fi

docker_args=(
  build
  --build-arg "NODE_IMAGE=$NODE_IMAGE"
  --build-arg "CLAUDE_CODE_VERSION=$CLAUDE_CODE_VERSION"
  --build-arg "CODEX_VERSION=$CODEX_VERSION"
  -t "$IMAGE"
)

if [[ "$PULL_BASE" == "1" ]]; then
  docker_args+=(--pull)
fi

docker_args+=("$REPO_ROOT")

for attempt in $(seq 1 "$BUILD_ATTEMPTS"); do
  echo "Docker build attempt $attempt/$BUILD_ATTEMPTS using base $NODE_IMAGE"
  if docker "${docker_args[@]}"; then
    exit 0
  fi

  if [[ "$attempt" -lt "$BUILD_ATTEMPTS" ]]; then
    sleep_seconds=$((attempt * 5))
    echo "Build failed; retrying in ${sleep_seconds}s..." >&2
    sleep "$sleep_seconds"
  fi
done

echo "Docker build failed after $BUILD_ATTEMPTS attempts." >&2
exit 1
