#!/bin/bash

# Define the path to the local AppImage
LOCAL_LOVE="$PWD/bin/love.AppImage"

# Check if the local AppImage exists
if [ -f "$LOCAL_LOVE" ]; then
    echo "Using local Love AppImage..."
    "$LOCAL_LOVE" "$PWD" "$@"
else
    echo "Local AppImage not found. Falling back to system default..."
    love "$PWD" "$@"
fi
