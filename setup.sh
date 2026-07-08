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

# Hump, Tween, Slab, Bump
git clone --depth 1 https://github.com/vrld/hump.git
git clone --depth 1 https://github.com/kikito/tween.lua.git tween
git clone --depth 1 https://github.com/flamendless/Slab.git
git clone --depth 1 https://github.com/kikito/bump.lua.git bump

# 4. Safely return to the project root
cd ..

echo "✅ Install complete! Your environment is ready."
