#!/usr/bin/env bash
set -eo pipefail

# -----------------------------------------------------------------
# Configuration & Gestion des arguments
# -----------------------------------------------------------------
AUTO_APPROVE=false
for arg in "$@"; do
    case $arg in
        -y|--yes)
            AUTO_APPROVE=true
            shift
            ;;
    esac
done

TEMPLATE_PATH="./templates"
FONT_NAME="0xProtoNerdFont-Regular"
FONT_DIR="${HOME}/.local/share/fonts"
[[ "$OSTYPE" == "darwin"* ]] && FONT_DIR="${HOME}/Library/Fonts"

# Couleurs pour les logs
C_RESET="\033[0m"
C_INFO="\033[36m"
C_SUCCESS="\033[32m"
C_WARN="\033[33m"
C_ERROR="\033[31m"

log_info() { echo -e "${C_INFO}ℹ️  $1${C_RESET}"; }
log_success() { echo -e "${C_SUCCESS}✅ $1${C_RESET}"; }
log_warn() { echo -e "${C_WARN}⚠️  $1${C_RESET}"; }
log_error() { echo -e "${C_ERROR}❌ $1${C_RESET}"; }

ask_confirmation() {
    local prompt="$1"
    if [ "$AUTO_APPROVE" = true ]; then
        return 0
    fi
    read -p "$prompt (Y/n): " yn
    yn=${yn:-Y}
    [[ "$yn" =~ ^[Yy]$ ]]
}

log_info "🚀 Démarrage de la configuration de l'environnement Zsh..."

# Vérification préliminaire du dossier templates
if [ ! -d "$TEMPLATE_PATH" ]; then
    log_error "Le dossier templates '$TEMPLATE_PATH' est introuvable."
    exit 1
fi

# -----------------------------------------------------------------
# Gestion des certificats d'entreprise / Proxy SSL
# -----------------------------------------------------------------
if [ -d "/etc/ssl/certs" ]; then
    if command -v update-ca-certificates &> /dev/null; then
        log_info "Mise à jour des certificats système..."
        update-ca-certificates --fresh || update-ca-certificates || true
    else
        log_warn "La commande 'update-ca-certificates' est introuvable. Des problèmes de chaîne SSL peuvent survenir lors du téléchargement de dépendances."
    fi
fi

# -----------------------------------------------------------------
# 1. Détection OS & Package Manager
# -----------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "linux"* ]]; then
    OS="linux"
else
    log_error "OS non supporté : $OSTYPE"
    exit 1
fi

detect_linux_package_manager() {
    if command -v apt &> /dev/null; then echo "apt"
    elif command -v dnf &> /dev/null; then echo "dnf"
    elif command -v yum &> /dev/null; then echo "yum"
    elif command -v pacman &> /dev/null; then echo "pacman"
    elif command -v apk &> /dev/null; then echo "apk"
    else echo "unknown"; fi
}

PKG_MANAGER=$(detect_linux_package_manager)

# -----------------------------------------------------------------
# 2. Fonctions d'installation résilientes
# -----------------------------------------------------------------
install_package() {
    local pkg=$1
    local SUDO=""

    if [[ $EUID -ne 0 ]] && command -v sudo &> /dev/null; then
        SUDO="sudo"
    fi

    if [[ "$OS" == "linux" ]]; then
        case "$PKG_MANAGER" in
            apt) $SUDO apt update && $SUDO apt install -y "$pkg" ;;
            dnf) $SUDO dnf install -y "$pkg" ;;
            yum) $SUDO yum install -y "$pkg" ;;
            pacman) $SUDO pacman -S --noconfirm "$pkg" ;;
            apk) $SUDO apk add "$pkg" ;;
            *)
                log_warn "Aucun gestionnaire de paquets pris en charge détecté. Impossible d'installer automatiquement '$pkg'."
                return 1
                ;;
        esac
    elif [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            if ask_confirmation "🍺 Homebrew non détecté. L'installer ?"; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [[ -d /opt/homebrew/bin ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [[ -d /home/linuxbrew/.linuxbrew/bin ]]; then
                    eval "$($(command -v brew) shellenv)"
                fi
            else
                log_warn "Installation de Homebrew ignorée."
                return 1
            fi
        fi
        brew install "$pkg"
    fi
}

install_fzf() {
    if command -v brew &> /dev/null && [[ "$OS" == "macos" ]]; then
        log_info "Installation de fzf via Homebrew..."
        brew install fzf
    else
        local FZF_DIR="$HOME/.fzf"
        if [ ! -d "$FZF_DIR" ]; then
            log_info "Installation de fzf depuis le dépôt officiel..."
            git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR" || { log_error "Échec du clonage fzf"; return 1; }
            "$FZF_DIR/install" --all
        else
            log_success "fzf est déjà installé dans $FZF_DIR"
        fi
    fi
}

install_nerd_font() {
    log_info "Vérification / Installation de la police Nerd Font ($FONT_NAME)..."
    mkdir -p "$FONT_DIR"

    if ls "$FONT_DIR"/*$FONT_NAME* &> /dev/null; then
        log_success "Police Nerd Font ($FONT_NAME) déjà présente."
        return 0
    fi

    local LOCAL_FONTS_DIR="./fonts"

    if [ -d "$LOCAL_FONTS_DIR" ] && ls "$LOCAL_FONTS_DIR"/*$FONT_NAME* &> /dev/null; then
        log_info "Installation de la police depuis le dossier local '$LOCAL_FONTS_DIR'..."
        cp "$LOCAL_FONTS_DIR"/*$FONT_NAME* "$FONT_DIR/"

        if [[ "$OS" == "linux" ]] && command -v fc-cache &> /dev/null; then
            fc-cache -f "$FONT_DIR"
        fi

        log_success "Police Nerd Font installée avec succès dans $FONT_DIR"
    else
        log_warn "Dossier '$LOCAL_FONTS_DIR' ou police '$FONT_NAME' introuvable. Copie de la police ignorée."
    fi
}

# -----------------------------------------------------------------
# 3. Prérequis
# -----------------------------------------------------------------
PREREQ_PKGS=(zsh git curl wget unzip)
MISSING_PKGS=()

for pkg in "${PREREQ_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warn "Paquets manquants : ${MISSING_PKGS[*]}"
    if ask_confirmation "Voulez-vous installer les paquets manquants ?"; then
        for pkg in "${MISSING_PKGS[@]}"; do
            log_info "Installation de $pkg..."
            install_package "$pkg" || log_warn "Échec de l'installation de $pkg"
        done
    else
        log_warn "Certains prérequis manquent, la suite pourrait échouer."
    fi
else
    log_success "Tous les prérequis système sont installés."
fi

if ! command -v fzf &> /dev/null; then
    install_fzf
fi

# Installer la police Nerd Font
install_nerd_font

# -----------------------------------------------------------------
# 4. Zinit (Gestionnaire de plugins Zsh)
# -----------------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
    log_info "Installation de Zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" || log_error "Échec de l'installation de Zinit"
else
    log_success "Zinit est déjà installé."
fi

# -----------------------------------------------------------------
# 5. Oh-My-Posh
# -----------------------------------------------------------------
if ! command -v oh-my-posh &> /dev/null; then
    log_info "Installation d'oh-my-posh..."
    if [[ "$OS" == "linux" ]]; then
        curl -s https://ohmyposh.dev/install.sh | bash -s || log_error "Échec de l'installation d'oh-my-posh"
    else
        brew install jandedobbeleer/oh-my-posh/oh-my-posh
    fi
else
    log_success "oh-my-posh est déjà installé."
fi

# -----------------------------------------------------------------
# 6. Configuration .zshrc
# -----------------------------------------------------------------
if [ -f "$HOME/.zshrc" ]; then
    if ask_confirmation "⚠️ .zshrc existe déjà. Faire une sauvegarde et le remplacer ?"; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.pre-omp"
        log_info "Sauvegarde créée : ~/.zshrc.pre-omp"
    else
        log_info "Remplacement de .zshrc ignoré."
    fi
fi

if [ -f "$TEMPLATE_PATH/config.zsh" ]; then
    cp "$TEMPLATE_PATH/config.zsh" "$HOME/.zshrc"
    log_success "Configuration Zsh appliquée."
else
    log_warn "Fichier '$TEMPLATE_PATH/config.zsh' introuvable, copie ignorée."
fi

# -----------------------------------------------------------------
# 7. Thème oh-my-posh (zen.toml)
# -----------------------------------------------------------------
CONFIG_DIR="$HOME/.config/ohmyposh"
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/zen.toml" ]; then
    if ask_confirmation "⚠️ zen.toml existe déjà. Le sauvegarder et le remplacer ?"; then
        mv "$CONFIG_DIR/zen.toml" "$CONFIG_DIR/zen.toml.old"
        log_info "Sauvegarde créée : zen.toml.old"
    else
        log_info "Remplacement de zen.toml ignoré."
    fi
fi

if [ -f "$TEMPLATE_PATH/zen.toml" ]; then
    cp "$TEMPLATE_PATH/zen.toml" "$CONFIG_DIR/zen.toml"
    log_success "Thème oh-my-posh copié dans $CONFIG_DIR/zen.toml"
else
    log_warn "Fichier '$TEMPLATE_PATH/zen.toml' introuvable, copie ignorée."
fi

# -----------------------------------------------------------------
# 8. Changement de Shell par défaut
# -----------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"

if [ -n "$ZSH_PATH" ]; then
    if ask_confirmation "❓ Voulez-vous définir Zsh comme shell par défaut ?"; then
        if chsh -s "$ZSH_PATH" 2>/dev/null || sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null; then
            log_success "Shell par défaut changé vers Zsh (effectif à la prochaine connexion)."
        else
            log_warn "Impossible de changer automatiquement le shell via chsh."
        fi
    fi
fi

# -----------------------------------------------------------------
# 9. Fin de script
# -----------------------------------------------------------------
log_success "✨ Configuration terminée avec succès !"

log_info "Lancement de Zsh..."
exec zsh
