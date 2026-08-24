#!/bin/bash

# Define the path to the local AppImage
EDITOR_LOCAL="$PWD/bin/tiled.AppImage"

# Check if the local AppImage exists
if [ -f "$EDITOR_LOCAL" ]; then
    echo "Using local bin..."
    "$EDITOR_LOCAL" "$PWD" "$@"
else
    echo "Local bin not found. Falling back to system default..."
    tiled "$PWD" "$@"
fi
