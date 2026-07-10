#!/bin/sh
set -e

if command -v luajit >/dev/null 2>&1; then
	luajit tests/run.lua "$@"
else
	lua tests/run.lua "$@"
fi
