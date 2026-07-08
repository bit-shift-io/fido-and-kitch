#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Always ensure the user's local bin is in the PATH for this script execution
export PATH="$HOME/.local/bin:$PATH"

# 1. Install dependencies based on OS
OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then
    if command -v pacman > /dev/null 2>&1; then
        echo "🐧 Arch Linux detected. Setting up makelove via pipx..."
        if ! command -v pipx > /dev/null 2>&1; then
            sudo pacman -S --noconfirm --needed python-pipx
            pipx ensurepath
        fi

        if ! command -v makelove > /dev/null 2>&1; then
            pipx install makelove
        fi

    elif command -v apt-get > /dev/null 2>&1; then
        echo "🐧 Debian/Ubuntu detected. Setting up makelove via pipx..."
        if ! command -v pipx > /dev/null 2>&1; then
            sudo apt update && sudo apt install -y pipx
            pipx ensurepath
        fi

        if ! command -v makelove > /dev/null 2>&1; then
            pipx install makelove
        fi
    fi

elif [ "$OS" = "Darwin" ]; then
    echo "🍏 macOS detected. Setting up makelove via Homebrew & Pip..."
    if command -v brew > /dev/null 2>&1; then
        if ! command -v pipx > /dev/null 2>&1; then
            brew install pipx
            pipx ensurepath
        fi

        if ! command -v makelove > /dev/null 2>&1; then
            pipx install makelove
        fi
    else
        echo "⚠️ Homebrew not found. Please install it to automate Love2D setup."
        exit 1
    fi
fi

# Force downgrade the package using runpip to bypass pipx inventory guards
if command -v makelove > /dev/null 2>&1; then
    echo "🔧 Forcing patch: Overwriting with legacy setuptools (<82) via runpip..."
    pipx runpip makelove install --upgrade "setuptools<82" > /dev/null 2>&1
fi

# 2. Interactive Build Menu
echo ""
echo "📦 Select a build target for makelove:"
echo "1) Windows 32-bit (win32)"
echo "2) Windows 64-bit (win64)"
echo "3) Linux AppImage (appimage)"
echo "4) macOS (macos)"
echo "5) Web/HTML5 (lovejs)"
echo "6) Exit"
echo ""
printf "Enter choice [1-6]: "
read -r CHOICE

case "$CHOICE" in
    1) TARGET="win32" ;;
    2) TARGET="win64" ;;
    3) TARGET="appimage" ;;
    4) TARGET="macos" ;;
    5) TARGET="lovejs" ;;
    6) echo "❌ Build canceled."; exit 0 ;;
    *) echo "⚠️ Invalid selection."; exit 1 ;;
esac

# 3. Run the build step
echo "🚀 Running makelove $TARGET..."
makelove "$TARGET"
