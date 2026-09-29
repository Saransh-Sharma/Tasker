#!/usr/bin/env bash
# Build everything: curated assets, both film sets in three formats, and the catalog page.
set -euo pipefail
cd "$(dirname "$0")"
node tools/curate-assets.mjs
bash teaser/build.sh "$@"
node tools/build-catalog.mjs
echo "open $(pwd)/index.html"
