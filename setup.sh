#!/usr/bin/env bash
set -e

echo "🚀 Setting up Zsh environment..."

# ------------------------
# 1. Vérification de l'OS
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
# 2. Vérification des prérequis
# ------------------------
install_package() {
    local pkg=$1
    if [[ "$OS" == "linux" ]]; then
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y "$pkg"
        else
            echo "❌ No supported package manager found. Install $pkg manually."
        fi
    elif [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            read -p "🍺 Homebrew is not installed. Install it now? (y/n): " yn
            if [[ "$yn" == "y" ]]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            else
                echo "⚠️ Skipping Homebrew installation. Some packages might be missing."
                return
            fi
        fi
        brew install "$pkg"
    fi
}

echo "✅ Checking and installing prerequisites..."
for pkg in zsh git curl wget fzf; do
    if ! command -v "$pkg" &> /dev/null; then
        echo "📦 $pkg is missing."
        read -p "Install $pkg? (y/n): " yn
        if [[ "$yn" == "y" ]]; then
            install_package "$pkg"
        else
            echo "⚠️ Skipping $pkg installation."
        fi
    fi
done

# ------------------------
# 3. Installation de oh-my-posh
# ------------------------
if ! command -v oh-my-posh &> /dev/null; then
    read -p "📦 oh-my-posh not installed. Install now? (y/n): " yn
    if [[ "$yn" == "y" ]]; then
        if [[ "$OS" == "linux" ]]; then
            curl -s https://ohmyposh.dev/install.sh | bash -s
        else
            brew install jandedobbeleer/oh-my-posh/oh-my-posh
        fi
    else
        echo "⚠️ Skipping oh-my-posh installation."
    fi
fi

# ------------------------
# 4. Sauvegarde de l'ancienne config et copie de la nouvelle
# ------------------------
if [ -f ~/.zshrc ]; then
    read -p "⚠️ .zshrc exists. Backup and replace it? (y/n): " yn
    if [[ "$yn" == "y" ]]; then
        mv ~/.zshrc ~/.zshrc.old
        echo "📂 Backed up to ~/.zshrc.old"
    else
        echo "⏭ Skipping .zshrc replacement."
        exit 0
    fi
fi

cp ./config.zsh ~/.zshrc
echo "✅ Copied new Zsh configuration."

# ------------------------
# 5. Recharger la config
# ------------------------
read -p "Reload Zsh now? (y/n): " yn
if [[ "$yn" == "y" ]]; then
    exec zsh
else
    echo "✅ Installation complete. Restart your terminal to apply changes."
fi
