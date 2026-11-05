#!/usr/bin/env bash
set -euo pipefail

rm -rf public
cp -r skills public
mkdir -p public/meta
cp -r meta/qdrant-advisor public/meta/qdrant-advisor

find public -name '*.md' -print0 | xargs -0 perl -pi -e 's|https://search\.qdrant\.tech/md/|/md/|g'

python3 scripts/make_links_absolute.py

python3 scripts/generate_llms_txt.py public

# Which docs pages each skill draws on, for the docs-to-skills automation (qdrant/documentation#167).
python3 scripts/build_docs_map.py --output public/docs-map.json

python3 scripts/generate_breadcrumbs.py public

# Last of the SKILL.md steps: the index carries a digest of each served file.
python3 scripts/generate_agent_skills_index.py public

bash scripts/generate_sitemap.sh public
