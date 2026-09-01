#!/usr/bin/env bash
# Post a PR comment, or update the existing one if a comment starting with the
# given marker already exists — so a re-triggered A/B test (label removed and
# re-added) edits its own prior scorecard instead of piling up duplicates.
#
# Requires `gh` authenticated (GH_TOKEN/GITHUB_TOKEN in env, as in Actions).
set -Eeuo pipefail

PR=""
MARKER=""
BODY_FILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/scoring/post-pr-comment.sh --pr N --marker STR --body-file FILE

The body file's first line must be the marker (an HTML comment, e.g.
"<!-- skill-ab-test:scorecard -->") so a prior comment can be found and
edited in place. Any existing PR comment whose body starts with MARKER is
updated; otherwise a new comment is created.

Options:
  --pr N            Pull request number.
  --marker STR      Marker string identifying this comment across runs.
  --body-file FILE  File with the full comment body (marker on line 1).
  -h, --help        Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR="${2:?}"; shift 2 ;;
    --marker) MARKER="${2:?}"; shift 2 ;;
    --body-file) BODY_FILE="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n "$PR" && -n "$MARKER" && -n "$BODY_FILE" ]] || { usage >&2; exit 64; }
[[ -f "$BODY_FILE" ]] || { echo "Body file not found: $BODY_FILE" >&2; exit 66; }
command -v gh >/dev/null 2>&1 || { echo "gh CLI is required" >&2; exit 64; }

existing_id="$(gh api "repos/{owner}/{repo}/issues/${PR}/comments" --paginate \
  --jq "[.[] | select(.body | startswith(\"${MARKER}\"))][0].id" 2>/dev/null || true)"

if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
  gh api --method PATCH "repos/{owner}/{repo}/issues/comments/${existing_id}" \
    -F body="@${BODY_FILE}" >/dev/null
  echo "Updated PR comment $existing_id"
else
  gh pr comment "$PR" --body-file "$BODY_FILE"
  echo "Created new PR comment"
fi
