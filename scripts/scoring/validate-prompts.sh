#!/usr/bin/env bash
# Preflight for the weekly scoring matrix: confirm every test-prompt's skill_url
# resolves to a real skill on disk. Read-only — touches nothing in the skills
# checkout. Exits non-zero (and lists every failure) so a renamed skill dir or a
# malformed skill_url breaks loudly here rather than as a confusing mid-run
# install failure or a false "skill unavailable".
#
# For each *.json under the prompts dir it checks:
#   - the file parses as JSON and has a non-empty string skill_url
#   - skill_url resolves (expected published-site host)
#   - skills/<family>/SKILL.md exists   (the install/availability unit)
#   - skills/<leaf_rel>       exists    (the activation/test-target unit)
#
# discord-* prompts are the held-out set: validated too (they share families and
# may be scored later), but counted separately.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults are in-repo (this script lives in the qdrant/skills repo).
PROMPTS_DIR="${PROMPTS_DIR:-$REPO_ROOT/evals/test-prompts}"
SKILLS_ROOT="${SKILLS_ROOT:-$REPO_ROOT/skills}"
VERBOSE="0"

usage() {
  cat <<'USAGE'
Usage: scripts/scoring/validate-prompts.sh [options]

Checks that every test-prompt skill_url resolves to a real skill on disk.

Options:
  --prompts-dir DIR   Directory of *.json test-prompts.
                      Default: ../skills/evals/test-prompts
  --skills-root DIR   Root the leaf paths are relative to (the skills/ dir).
                      Default: ../skills/skills
  --verbose           Print an OK line for every prompt, not just failures.
  -h, --help          Show this help.

Exit codes: 0 all resolve · 1 one or more failed · 64 bad usage · 66 dir missing
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompts-dir) PROMPTS_DIR="${2:?--prompts-dir needs a value}"; shift 2 ;;
    --skills-root) SKILLS_ROOT="${2:?--skills-root needs a value}"; shift 2 ;;
    --verbose)     VERBOSE="1"; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 64
fi

# shellcheck source=resolve-skill.sh
source "$SCRIPT_DIR/resolve-skill.sh"

if [[ ! -d "$PROMPTS_DIR" ]]; then
  echo "Prompts dir not found: $PROMPTS_DIR" >&2
  exit 66
fi
if [[ ! -d "$SKILLS_ROOT" ]]; then
  echo "Skills root not found: $SKILLS_ROOT" >&2
  exit 66
fi

echo "Prompts: $PROMPTS_DIR"
echo "Skills:  $SKILLS_ROOT"
echo

fail=0
n=0
scored=0
heldout=0

report_fail() {
  # base, message
  printf 'FAIL  %-52s %s\n' "$1" "$2"
  fail=1
}

shopt -s nullglob
for f in "$PROMPTS_DIR"/*.json; do
  n=$((n + 1))
  base="$(basename "$f")"
  if [[ "$base" == discord-* ]]; then
    heldout=$((heldout + 1))
  else
    scored=$((scored + 1))
  fi

  if ! jq -e . "$f" >/dev/null 2>&1; then
    report_fail "$base" "invalid JSON"
    continue
  fi

  url="$(jq -r 'if (.skill_url | type) == "string" and (.skill_url | length > 0) then .skill_url else empty end' "$f")"
  if [[ -z "$url" ]]; then
    report_fail "$base" "missing or empty skill_url"
    continue
  fi

  if ! resolved="$(resolve_skill "$url")"; then
    report_fail "$base" "unexpected host: $url"
    continue
  fi
  family="${resolved%%$'\t'*}"
  leaf="${resolved#*$'\t'}"

  problems=()
  [[ -f "$SKILLS_ROOT/$family/SKILL.md" ]] || problems+=("no family SKILL.md ($family/SKILL.md)")
  [[ -f "$SKILLS_ROOT/$leaf" ]] || problems+=("no leaf ($leaf)")

  if [[ ${#problems[@]} -gt 0 ]]; then
    report_fail "$base" "$(IFS='; '; echo "${problems[*]}")"
    continue
  fi

  if [[ "$VERBOSE" == "1" ]]; then
    printf 'OK    %-52s %s\n' "$base" "$family"
  fi
done

echo
if [[ "$n" -eq 0 ]]; then
  echo "No *.json prompts found under $PROMPTS_DIR" >&2
  exit 1
fi

echo "Checked $n prompts ($scored scored, $heldout held-out)."
if [[ "$fail" -eq 0 ]]; then
  echo "All resolve. ✓"
else
  echo "One or more prompts failed to resolve. ✗"
fi
exit "$fail"
