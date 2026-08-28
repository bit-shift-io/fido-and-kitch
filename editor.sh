#!/bin/bash

# Define the path to the local AppImage
LOCAL_BIN="$PWD/bin/tiled.AppImage"
PROJECT_FILE="res/editor/fido-and-kitch.tiled-project"

# Check if the local AppImage exists
if [ -f "$LOCAL_BIN" ]; then
    echo "Using local bin..."
    "$LOCAL_BIN" "$PROJECT_FILE" "$@"
else
    echo "Local bin not found. Falling back to system default..."
    tiled "$PROJECT_FILE" "$@"
fi
