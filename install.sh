#!/usr/bin/env bash
#
# Install script for "Mango Style" dotfiles for MangoWM.
# Configs are for the following: MangoWM, Waybar and Rofi.
# This script installs all needed packages and yay if not already installed.
#

set -euo pipefail

#  CONFIGURATION

CODEBERG_REPO="https://codeberg.org/YOUR_USERNAME/YOUR_REPO.git"
REPO_DIR="/tmp/mangostyle-dotfiles"

PACMAN_PACKAGES=(
    git
    base-devel
    make
    gcc
    # starship
)

AUR_PACKAGES=(
    # yay

)

# Config mapping: "REPO_RELATIVE_PATH -> DESTINATION"
CONFIG_MAP=(
    "mango               -> $HOME/.config/mango"
    "waybar              -> $HOME/.config/waybar"
    "rofi                -> $HOME/.config/rofi"
    "Wallpapers          -> $HOME/Wallpapers"
)

BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; }
die()     { error "$*"; exit 1; }

confirm() {
    local prompt="$1"
    local reply
    read -rp "$(echo -e "${YELLOW}${BOLD}[?]${RESET} ${prompt} [y/N] ")" reply
    [[ "${reply,,}" == "y" ]]
}

backup_and_copy() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    [[ -e "$dst" || -L "$dst" ]] && rm -rf "$dst"

    if [[ -d "$src" ]]; then
        cp -r "$src" "$dst"
    else
        cp "$src" "$dst"
    fi
    success "Copied $src → $dst"
}

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        die "Do not run this script as root. It will call sudo when needed."
    fi
}

check_internet() {
    info "Checking internet connectivity..."
    if ! ping -c1 -W3 codeberg.org &>/dev/null; then
        die "No connection to codeberg.org. Check your network."
    fi
    success "Internet OK"
}

# PACKAGE INSTALLATION

install_yay() {
    if command -v yay &>/dev/null; then
        success "yay is already installed ($(yay --version | head -1))"
        return
    fi

    info "yay not found — installing from AUR..."
    local tmp
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    success "yay installed"
}

install_pacman_packages() {
    if [[ ${#PACMAN_PACKAGES[@]} -eq 0 ]]; then
        info "No pacman packages configured, skipping."
        return
    fi

    info "Updating pacman database..."
    sudo pacman -Sy --noconfirm

    info "Installing pacman packages: ${PACMAN_PACKAGES[*]}"
    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
    success "pacman packages installed"
}

install_aur_packages() {
    if [[ ${#AUR_PACKAGES[@]} -eq 0 ]]; then
        info "No AUR packages configured, skipping."
        return
    fi

    info "Installing AUR packages: ${AUR_PACKAGES[*]}"
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
    success "AUR packages installed"
}

# DOTFILES

clone_repo() {
    info "Cloning $CODEBERG_REPO → $REPO_DIR"
    rm -rf "$REPO_DIR"
    git clone "$CODEBERG_REPO" "$REPO_DIR"
    success "Repo cloned"
}

backup_existing_configs() {
    local backup_dir="$HOME/dotfiles-backup-$(date +%Y%m%d_%H%M%S)"
    local backed_up=0

    info "Scanning for existing configs to back up..."

    for entry in "${CONFIG_MAP[@]}"; do
        local dst
        dst=$(echo "$entry" | awk -F' -> ' '{print $2}' | xargs)
        dst="${dst/#\~/$HOME}"

        if [[ -e "$dst" || -L "$dst" ]]; then
            local rel="${dst#"$HOME"/}"
            local backup_target="$backup_dir/$rel"
            mkdir -p "$(dirname "$backup_target")"
            cp -r "$dst" "$backup_target"
            info "  Backed up: $dst"
            backed_up=$(( backed_up + 1 ))
        fi
    done

    if [[ "$backed_up" -eq 0 ]]; then
        info "No existing configs found — nothing to back up."
    else
        success "$backed_up item(s) backed up to $backup_dir"
    fi
}

deploy_configs() {
    if [[ ${#CONFIG_MAP[@]} -eq 0 ]]; then
        info "No config mappings defined, skipping."
        return
    fi

    info "Deploying config files..."
    for entry in "${CONFIG_MAP[@]}"; do
        local src_rel dst
        src_rel=$(echo "$entry" | awk -F' -> ' '{print $1}' | xargs)
        dst=$(echo "$entry"     | awk -F' -> ' '{print $2}' | xargs)
        dst="${dst/#\~/$HOME}"

        local src="$REPO_DIR/$src_rel"

        if [[ ! -e "$src" ]]; then
            warn "Source not found in repo, skipping: $src"
            continue
        fi

        backup_and_copy "$src" "$dst"
    done
    success "Config installation complete"
}

# MAIN

main() {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}   Mango Style Setup Script${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}\n"

    check_not_root
    check_internet

    if confirm "Install pacman packages?"; then
        install_pacman_packages
    fi

    if confirm "Install/update yay?"; then
        install_yay
    fi

    if confirm "Install AUR packages?"; then
        install_aur_packages
    fi

    if confirm "Clone dotfiles repo and deploy configs?"; then
        clone_repo
        if confirm "Back up existing configs before deploying?"; then
            backup_existing_configs
        fi
        deploy_configs
    fi

    echo ""
    success "All done! Restart your system for everything to apply properly."
}

main "$@"
