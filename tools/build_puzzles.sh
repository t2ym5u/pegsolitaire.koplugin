#!/bin/bash
# Rebuilds ../puzzles_data.lua from puzzles_src.lua (about 1 min), then the
# pagodas (build_pagodas.sh). Fails if any puzzle is not solvable.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
luajit "$here/build_puzzles.lua" > "$here/../puzzles_data.lua.new"
mv "$here/../puzzles_data.lua.new" "$here/../puzzles_data.lua"
"$here/build_pagodas.sh"
