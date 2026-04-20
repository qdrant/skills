#!/usr/bin/env bash
set -euo pipefail

rm -rf public
cp -r skills public
cp README.md public/index.md
