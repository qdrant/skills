#!/usr/bin/env bash
set -euo pipefail

rm -rf public
cp -r skills public

bash scripts/generate_sitemap.sh public
