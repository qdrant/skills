#!/usr/bin/env bash
# Shared skill resolver for the weekly scoring framework.
#
# Maps a test-prompt's skill_url to the two units scoring needs:
#   family   = first path segment  -> install/staging target + availability key
#   leaf_rel = full path under skills/ -> activation target + provenance
#
# The mapping is a pure string parse of skill_url; nothing here touches disk.
# Filesystem existence is checked by validate-prompts.sh, which sources this.
#
# Source it to get resolve_skill(), or run directly on one URL:
#   scripts/scoring/resolve-skill.sh https://skills.qdrant.tech/qdrant-scaling/minimize-latency/SKILL.md
#   -> qdrant-scaling<TAB>qdrant-scaling/minimize-latency/SKILL.md
set -Eeuo pipefail

# Every skill_url is expected to live on the published site. A URL that does not
# start with this prefix (e.g. a stray GitHub blob link) is a resolution failure,
# not something to silently coerce.
SKILL_URL_PREFIX="https://skills.qdrant.tech/"

# resolve_skill URL
# On success: prints "family<TAB>leaf_rel", returns 0.
# On a non-matching host: prints nothing, returns 1.
resolve_skill() {
  local url="$1"
  local path="${url#"$SKILL_URL_PREFIX"}"
  if [[ "$path" == "$url" ]]; then
    return 1 # url did not start with the expected host prefix
  fi
  local family="${path%%/*}"
  printf '%s\t%s\n' "$family" "$path"
}

# Direct execution: resolve a single URL for quick inspection.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "Usage: resolve-skill.sh SKILL_URL" >&2
    exit 64
  fi
  if ! resolve_skill "$1"; then
    echo "Unrecognized skill_url host (expected ${SKILL_URL_PREFIX}...): $1" >&2
    exit 65
  fi
fi
