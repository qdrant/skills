#!/usr/bin/env bash
# Given a set of changed files under skills/ (one per line on stdin), find every
# scored (non-discord-) test-prompt whose skill_url LEAF (not just its family)
# was touched, and copy those prompt JSONs into an output directory.
#
# Used by the A/B test workflow to scope a PR-triggered run to only the
# prompt(s) that exercise the exact skill the PR touches. Matching at the leaf
# level rather than the family level matters for cost: run-eval-matrix.sh's
# with-skill install stages the whole top-level family (unavoidable — a leaf's
# relative links need its siblings on disk), but a family can have many leaves
# and many scored prompts (e.g. qdrant-scaling has 8). A one-leaf change should
# score the one prompt that targets it, not the whole family's prompt set.
#
# A prompt matches if the changed-files list contains its leaf's SKILL.md, or
# any file under the leaf's directory (a resource file, not just SKILL.md).
#
# Usage:
#   git diff --name-only "$BASE_SHA" "$HEAD_SHA" -- skills/ \
#     | scripts/scoring/match-changed-prompts.sh --out-dir /tmp/ab-prompts
#
# Prints the matched leaf directories (one per line) to stdout for logging, and
# the count of matched prompts to stderr as "MATCHED=<n>".
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=resolve-skill.sh
source "$SCRIPT_DIR/resolve-skill.sh"

PROMPTS_DIR="${PROMPTS_DIR:-$REPO_ROOT/evals/test-prompts}"
OUT_DIR=""

usage() {
  cat <<'USAGE'
Usage: git diff --name-only BASE HEAD -- skills/ | match-changed-prompts.sh --out-dir DIR

Options:
  --out-dir DIR       Where to copy matched prompt JSONs. Required.
  --prompts-dir DIR   Test-prompt JSONs to search. Default: ../evals/test-prompts
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:?}"; shift 2 ;;
    --prompts-dir) PROMPTS_DIR="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n "$OUT_DIR" ]] || { echo "--out-dir is required" >&2; usage >&2; exit 64; }
[[ -d "$PROMPTS_DIR" ]] || { echo "Prompts dir not found: $PROMPTS_DIR" >&2; exit 66; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 64; }

mkdir -p "$OUT_DIR"

# Portable to bash 3.2 (macOS default) — no associative arrays, per the same
# convention as run-eval-matrix.sh.
CHANGED_FILE="$(mktemp)"
LEAVES_FILE="$(mktemp)"
trap 'rm -f "$CHANGED_FILE" "$LEAVES_FILE"' EXIT
grep -v '^[[:space:]]*$' > "$CHANGED_FILE" || true

if [[ ! -s "$CHANGED_FILE" ]]; then
  echo "No changed files under skills/ — nothing to match." >&2
  echo "MATCHED=0" >&2
  exit 0
fi

matched=0
for f in "$PROMPTS_DIR"/*.json; do
  base="$(basename "$f")"
  [[ "$base" == discord-* ]] && continue

  url="$(jq -r 'if (.skill_url | type) == "string" then .skill_url else empty end' "$f")"
  [[ -n "$url" ]] || continue

  resolved="$(resolve_skill "$url")" || continue
  leaf="${resolved#*$'\t'}"       # e.g. qdrant-scaling/minimize-latency/SKILL.md
  leaf_dir="${leaf%/*}"           # e.g. qdrant-scaling/minimize-latency

  if grep -qxF "skills/$leaf" "$CHANGED_FILE" || grep -q "^skills/${leaf_dir}/" "$CHANGED_FILE"; then
    cp "$f" "$OUT_DIR/"
    matched=$((matched + 1))
    echo "$leaf_dir" >> "$LEAVES_FILE"
  fi
done

sort -u "$LEAVES_FILE"
echo "MATCHED=$matched" >&2
