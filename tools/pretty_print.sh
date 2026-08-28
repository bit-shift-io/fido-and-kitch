#!/bin/bash

# Find the project root relative to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Processing JSON files in project root: $PROJECT_ROOT"

find "$PROJECT_ROOT" -type f \( -name "*.json" -o -name "*.tmj" -o -name "*.tj" -o -name "*.tsj" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -exec sh -c '
  for file; do
    if jq . "$file" > "$file.tmp" 2>/dev/null; then
      mv "$file.tmp" "$file"
      echo "Formatted: $file"
    else
      rm -f "$file.tmp"
      echo "Error/Skipped (invalid JSON): $file"
    fi
  done
' sh {} +
