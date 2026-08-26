#!/bin/bash

# Define the path to the local AppImage
LOCAL_BIN="$PWD/bin/tiled.AppImage"

# Check if the local AppImage exists
if [ -f "$LOCAL_BIN" ]; then
    echo "Using local bin..."
    "$LOCAL_BIN" "$PWD" "$@"
else
    echo "Local bin not found. Falling back to system default..."
    tiled "$PWD" "$@"
fi
