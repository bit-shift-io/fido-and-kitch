#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Starting clean environment setup..."

# 1. Install Love2D based on OS
OS="$(uname -s)"
if [ "$OS" = "Linux" ]; then
    if command -v pacman &> /dev/null; then
        echo "🐧 Arch Linux detected. Installing Love2D via pacman..."
        sudo pacman -S love --noconfirm --needed
    elif command -v apt-get &> /dev/null; then
        echo "🐧 Debian/Ubuntu detected. Installing Love2D via apt..."
        sudo apt update && sudo apt install -y love
    fi
elif [ "$OS" = "Darwin" ]; then
    echo "🍏 macOS detected. Installing Love2D via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install --cask love
    else
        echo "⚠️ Homebrew not found. Please install it to automate Love2D setup."
    fi
fi

# 2. Refresh the lib directory
echo "🧹 Cleaning up old libraries..."
rm -rf lib
mkdir -p lib
cd lib

# 3. Clone dependencies
echo "📦 Fetching dependencies..."

# STI (Simple Tiled Implementation)
git clone --depth 1 https://github.com/karai17/Simple-Tiled-Implementation.git
mv Simple-Tiled-Implementation/sti .
rm -rf Simple-Tiled-Implementation

# xml2lua removed (2026-08-28): XML/.tsx parsing was deleted in the
# non-JSON map-format removal. Only JSON map/template/tileset loading remains.

# Hump, Tween, Slab, Bump
git clone --depth 1 https://github.com/vrld/hump.git
git clone --depth 1 https://github.com/kikito/tween.lua.git tween
git clone --depth 1 https://github.com/flamendless/Slab.git
git clone --depth 1 https://github.com/kikito/bump.lua.git bump

# dkjson (single-file JSON lib required by the IPC server's game_api)
curl -sL -o dkjson.lua https://raw.githubusercontent.com/LuaDist/dkjson/master/dkjson.lua

# 4. Safely return to the project root
cd ..

# 5. Apply local patches to vendored libraries (lib/ is gitignored, so these
# fixes can't just live as edits to the cloned files -- see patches/*.patch)
echo "🩹 Applying local patches to vendored libraries..."
git apply patches/sti.patch
git apply patches/bump.patch

echo "✅ Install complete! Your environment is ready."
