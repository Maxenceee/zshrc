#!/usr/bin/env bash
set -e

echo "🚀 Setting up Neovim + NvChad (starter) environment..."

# ------------------------
# 1. Detect OS
# ------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

# ------------------------
# 2. Install package function
# ------------------------
install_package() {
    local pkg=$1
    local SUDO=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            echo "⚠️ Not root and sudo not found. Trying to install without privileges..."
        fi
    fi

    if [[ "$OS" == "linux" ]]; then
        if command -v apt &> /dev/null; then
            $SUDO apt update && $SUDO apt install -y "$pkg"
        else
            echo "❌ No supported package manager found. Install $pkg manually: $pkg"
        fi
    elif [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            echo "🍺 Homebrew not found. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install "$pkg"
    fi
}

# ------------------------
# 3. Prerequisites
# ------------------------
PREREQ_PKGS=(git curl unzip gcc neovim)

MISSING_PKGS=()
for pkg in "${PREREQ_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "The following packages are required but missing: ${MISSING_PKGS[*]}"
    read -p "Do you want to install them now? (Y/n) " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        for pkg in "${MISSING_PKGS[@]}"; do
            echo "📦 Installing $pkg..."
            install_package "$pkg"
        done
    else
        echo "⚠️ Some required packages are missing. The script may not work correctly."
    fi
else
    echo "✅ All prerequisites are already installed."
fi

# ------------------------
# 4. Install starterNvChad
# ------------------------
NVCHAD_DIR="$HOME/.config/nvim"
STARTER_REPO="https://github.com/NvChad/starter"

if [ -d "$NVCHAD_DIR" ]; then
    read -p "⚠️ NvChad config already exists. Backup and replace it? (Y/n): " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        mv "$NVCHAD_DIR" "$NVCHAD_DIR.backup"
        echo "📂 Backed up existing NvChad config to $NVCHAD_DIR.backup"
    else
        echo "⏭ Skipping NvChad installation."
        exit 0
    fi
fi

echo "📦 Installing starterNvChad..."
git clone --depth 1 "$STARTER_REPO" "$NVCHAD_DIR"
echo "✅ starterNvChad installed in $NVCHAD_DIR"

# ------------------------
# 5. Sync NvChad plugins
# ------------------------
echo "⚡ Running nvim +PackerSync..."
nvim +PackerSync +qall || echo "⚠️ Plugin sync may require running nvim manually."

echo "🎉 Neovim + NvChad (starter) setup complete!"
