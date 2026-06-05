#!/usr/bin/env bash
set -euo pipefail

rm -rf public
cp -r skills public

find public -name '*.md' -print0 | xargs -0 sed -i 's|https://search\.qdrant\.tech/md/|/md/|g'

python3 scripts/make_links_absolute.py

bash scripts/generate_sitemap.sh public
