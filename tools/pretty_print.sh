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

echo ""
echo "Formatting Lua files with stylua: $PROJECT_ROOT"

# Format project-authored Lua only: the root entrypoints plus src/, tools/,
# and tests/. Third-party / vendored Lua (lib/, src/physics/bump/) is left
# untouched so the diff stays focused on code we own.
if ! command -v stylua >/dev/null 2>&1; then
  echo "stylua not found on PATH; skipping Lua formatting (install it, e.g. 'cargo install stylua')."
  exit 0
fi

LUA_FILES="$(find "$PROJECT_ROOT" -type f -name "*.lua" \
  -not -path "*/lib/*" \
  -not -path "*/src/physics/bump/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*")"

if [ -z "$LUA_FILES" ]; then
  echo "No Lua files found to format."
else
  echo "$LUA_FILES" | xargs stylua
  echo "Formatted $(echo "$LUA_FILES" | grep -c '\.lua$') Lua file(s)."
fi

