#!/bin/sh
# Procedural level generator launcher. Runs from the repo root (relative
# requires and output paths depend on it) regardless of the caller's cwd.
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$SCRIPT_DIR"

mkdir -p res/map/generated

if command -v luajit >/dev/null 2>&1; then
	exec luajit tools/level_generator/main.lua "$@"
else
	exec lua tools/level_generator/main.lua "$@"
fi
