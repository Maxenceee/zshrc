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

log_info "🚀 Démarrage de la configuration de Neovim + NvChad..."

# -----------------------------------------------------------------
# Gestion des certificats d'entreprise / Proxy SSL
# -----------------------------------------------------------------
if [ -d "/etc/ssl/certs" ]; then
    if command -v update-ca-certificates &> /dev/null; then
        log_info "Mise à jour des certificats système..."
        update-ca-certificates --fresh || update-ca-certificates || true
    else
        log_warn "La commande 'update-ca-certificates' est introuvable. Des problèmes de chaîne SSL peuvent survenir."
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

# -----------------------------------------------------------------
# 3. Prérequis
# -----------------------------------------------------------------
PREREQ_PKGS=(git curl unzip gcc nvim)
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
            # Mapping si le paquet porte un nom différent sur apt (ex: neovim vs nvim)
            pkg_to_install="$pkg"
            [[ "$pkg" == "nvim" ]] && pkg_to_install="neovim"
            
            install_package "$pkg_to_install" || log_warn "Échec de l'installation de $pkg_to_install"
        done
    else
        log_warn "Certains prérequis manquent, la suite pourrait échouer."
    fi
else
    log_success "Tous les prérequis système sont installés."
fi

# -----------------------------------------------------------------
# 4. Installation de NvChad (Starter)
# -----------------------------------------------------------------
NVCHAD_DIR="$HOME/.config/nvim"
STARTER_REPO="https://github.com/NvChad/starter"

if [ -d "$NVCHAD_DIR" ]; then
    if ask_confirmation "⚠️ La configuration Neovim existe déjà. Faire une sauvegarde et la remplacer ?"; then
        BACKUP_DIR="${NVCHAD_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$NVCHAD_DIR" "$BACKUP_DIR"
        log_info "Sauvegarde créée : $BACKUP_DIR"
    else
        log_info "Installation de NvChad ignorée."
        exit 0
    fi
fi

log_info "Clonage de NvChad (starter)..."
mkdir -p "$(dirname "$NVCHAD_DIR")"
git clone --depth 1 "$STARTER_REPO" "$NVCHAD_DIR" || { log_error "Échec du clonage de NvChad"; exit 1; }
log_success "NvChad installé dans $NVCHAD_DIR"

# -----------------------------------------------------------------
# 5. Synchronisation des plugins
# -----------------------------------------------------------------
log_info "Initialisation et installation des plugins NvChad..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || log_warn "La synchro headless peut nécessiter d'ouvrir nvim manuellement une première fois."

log_success "🎉 Configuration de Neovim + NvChad terminée avec succès !"
