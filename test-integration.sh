#!/bin/sh
set -e

if command -v luajit >/dev/null 2>&1; then
	luajit tests/integration/run.lua "$@"
else
	lua tests/integration/run.lua "$@"
fi
