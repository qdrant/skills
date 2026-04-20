#!/usr/bin/env bash
set -euo pipefail

rm -rf public
cp -r skills public
cp index.md public/index.md
