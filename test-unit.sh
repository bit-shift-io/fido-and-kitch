#!/bin/sh
set -e

if command -v luajit >/dev/null 2>&1; then
	luajit tests/unit/run.lua "$@"
else
	lua tests/unit/run.lua "$@"
fi
