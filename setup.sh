#!/usr/bin/env bash
set -e

echo "🚀 Setting up Zsh environment..."

template_path="./templates"

# ------------------------
# 1. Détection OS
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
# 2. Fonction installation
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
            echo "❌ No supported package manager found. Install $pkg manually."
        fi
    elif [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            read -p "🍺 Homebrew not installed. Install it now? (Y/n): " yn
            yn=${yn:-Y}
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            else
                echo "⚠️ Skipping Homebrew installation. Some packages might be missing."
                return
            fi
        fi
        brew install "$pkg"
    fi
}

install_fzf() {
    if command -v brew &> /dev/null; then
        echo "📦 Installing fzf via Homebrew..."
        brew install fzf
    else
        local FZF_DIR="$HOME/.fzf"
        if [ ! -d "$FZF_DIR" ]; then
            echo "📦 Installing fzf from official repo..."
            git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
            "$FZF_DIR/install" --all
        else
            echo "✅ fzf already installed in $FZF_DIR"
        fi
    fi
}

# ------------------------
# 3. Prérequis (installation automatique)
# ------------------------
PREREQ_PKGS=(zsh git curl wget unzip)

# Vérifier quels paquets manquent
MISSING_PKGS=()
for pkg in "${PREREQ_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "Les paquets suivants sont nécessaires mais manquants : ${MISSING_PKGS[*]}"
    read -p "Voulez-vous les installer maintenant ? (Y/n) " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        for pkg in "${MISSING_PKGS[@]}"; do
            echo "📦 Installation de $pkg..."
            install_package "$pkg"
        done
    else
        echo "⚠️ Certains paquets nécessaires ne sont pas installés. Le script peut ne pas fonctionner correctement."
    fi
else
    echo "✅ Tous les paquets prérequis sont déjà installés."
fi

if ! command -v fzf &> /dev/null; then
    install_fzf
fi

# ------------------------
# 4. Zinit (auto)
# ------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    echo "📦 Installing Zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# ------------------------
# 5. Oh-my-posh (auto)
# ------------------------
if ! command -v oh-my-posh &> /dev/null; then
    echo "📦 Installing oh-my-posh..."
    if [[ "$OS" == "linux" ]]; then
        curl -s https://ohmyposh.dev/install.sh | bash -s
    else
        brew install jandedobbeleer/oh-my-posh/oh-my-posh
    fi
fi

# ------------------------
# 6. Sauvegarde .zshrc
# ------------------------
if [ -f ~/.zshrc ]; then
    read -p "⚠️ .zshrc exists. Backup and replace it? (Y/n): " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        mv ~/.zshrc ~/.zshrc.pre-omp
        echo "📂 Backed up to ~/.zshrc.pre-omp"
    else
        echo "⏭ Skipping .zshrc replacement."
        exit 0
    fi
fi

cp $template_path/config.zsh ~/.zshrc
echo "✅ Copied new Zsh configuration."

# ------------------------
# 7. Ajout du thème oh-my-posh (zen.toml)
# ------------------------
CONFIG_DIR="$HOME/.config/ohmyposh"
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/zen.toml" ]; then
    read -p "⚠️ zen.toml exists. Backup and replace it? (Y/n): " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        mv "$CONFIG_DIR/zen.toml" "$CONFIG_DIR/zen.toml.old"
        echo "📂 Backed up old zen.toml to zen.toml.old"
    else
        echo "⏭ Skipping zen.toml replacement."
        exit 0
    fi
fi

cp $template_path/zen.toml "$CONFIG_DIR/zen.toml"
echo "✅ Added oh-my-posh theme to $CONFIG_DIR/zen.toml"

# ------------------------
# 8. Changement de shell par défaut
# ------------------------
if [[ $(command -v dscl &> /dev/null) ]]; then
    DEFAULT_SHELL=$(dscl . -read /Users/"$USER" UserShell | awk '{print $2}')
else
    DEFAULT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
fi

if [[ "$DEFAULT_SHELL" != *"zsh" ]]; then
	read -p "❓ Your default shell is currently: $DEFAULT_SHELL. Do you want to change it to Zsh? (Y/n): " yn
	yn=${yn:-Y}
	if [[ "$yn" =~ ^[Yy]$ ]]; then
		chsh -s "$(command -v zsh)"
		echo "✅ Default shell changed to Zsh."
		echo "Note: This change will take effect on your next login."
	else
		echo "⏭ Skipping shell change."
	fi
fi
fi

# ------------------------
# 9. Rechargement automatique
# ------------------------
echo "🔄 Reloading Zsh..."
exec zsh
