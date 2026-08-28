#!/usr/bin/env bash
# Given a set of changed files under skills/ (one per line on stdin), find every
# scored (non-discord-) test-prompt whose skill_url family is among the changed
# families, and copy those prompt JSONs into an output directory.
#
# Used by the A/B test workflow to scope a PR-triggered run to only the
# prompt(s) that exercise the skill(s) the PR touches, so it does not re-score
# the whole 26-prompt matrix for a one-skill change.
#
# Usage:
#   git diff --name-only "$BASE_SHA" "$HEAD_SHA" -- skills/ \
#     | scripts/scoring/match-changed-prompts.sh --out-dir /tmp/ab-prompts
#
# Prints the matched family names (one per line) to stdout for logging, and the
# count of matched prompts to stderr as "MATCHED=<n>".
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

# Changed families: first path segment after "skills/" for every changed file.
# Portable to bash 3.2 (macOS default) — no associative arrays, per the same
# convention as run-eval-matrix.sh.
FAMILIES_FILE="$(mktemp)"
trap 'rm -f "$FAMILIES_FILE"' EXIT
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  rest="${path#skills/}"
  [[ "$rest" == "$path" ]] && continue # not under skills/
  family="${rest%%/*}"
  [[ -n "$family" ]] && echo "$family"
done | sort -u > "$FAMILIES_FILE"

if [[ ! -s "$FAMILIES_FILE" ]]; then
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
  family="${resolved%%$'\t'*}"

  if grep -qxF "$family" "$FAMILIES_FILE"; then
    cp "$f" "$OUT_DIR/"
    matched=$((matched + 1))
  fi
done

cat "$FAMILIES_FILE"
echo "MATCHED=$matched" >&2
