#!/usr/bin/env bash
set -euo pipefail

# On production, URL is the custom domain (skills.qdrant.tech); DEPLOY_PRIME_URL
# there is the branch permalink (main--qdrant-skills.netlify.app). On previews
# and branch deploys, prefer DEPLOY_PRIME_URL so links match the viewed deploy.
if [ "${CONTEXT:-}" = "production" ]; then
  BASE_URL="${SITE_URL:-${URL:-https://skills.qdrant.tech}}"
else
  BASE_URL="${SITE_URL:-${DEPLOY_PRIME_URL:-${URL:-https://skills.qdrant.tech}}}"
fi
BASE_URL="${BASE_URL%/}"
PUBLIC_DIR="${1:-public}"
OUTPUT="${PUBLIC_DIR}/sitemap.xml"
TODAY=$(date -u +"%Y-%m-%d")

cat > "$OUTPUT" <<'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
HEADER

find "$PUBLIC_DIR" -name '*.md' -type f | sort | while read -r file; do
  path="${file#"$PUBLIC_DIR"}"
  # index.md is served at /
  if [ "$path" = "/index.md" ]; then
    loc="${BASE_URL}/"
  else
    loc="${BASE_URL}${path}"
  fi

  cat >> "$OUTPUT" <<EOF
  <url>
    <loc>${loc}</loc>
    <lastmod>${TODAY}</lastmod>
  </url>
EOF
done

echo "</urlset>" >> "$OUTPUT"

echo "Sitemap generated at ${OUTPUT} ($(grep -c '<url>' "$OUTPUT") URLs)"
