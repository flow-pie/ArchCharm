#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  ArchCharm - Uninstall Script                                   ║
# ║  Removes symlinks and restores backups                          ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

info() { echo -e "${CYAN}[i]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
error() { echo -e "${RED}[✗]${RESET} $*"; }

readonly SYMLINKS=(
    "${HOME}/.config/niri"
    "${HOME}/.config/fish"
    "${HOME}/.config/alacritty"
    "${HOME}/.config/kitty"
    "${HOME}/.config/foot"
    "${HOME}/.config/nvim"
    "${HOME}/.config/waybar"
    "${HOME}/.config/noctalia"
    "${HOME}/.config/fastfetch"
    "${HOME}/.config/mako"
    "${HOME}/.config/fuzzel"
    "${HOME}/.config/swaylock"
    "${HOME}/.config/wlogout"
    "${HOME}/.config/cava"
    "${HOME}/.config/lazygit"
    "${HOME}/.config/bottom"
    "${HOME}/.config/tmux"
    "${HOME}/.config/mpv"
    "${HOME}/.config/yazi"
    "${HOME}/.config/ranger"
    "${HOME}/.config/prompt"
    "${HOME}/.config/walker"
    "${HOME}/.config/mimeapps.list"
    "${HOME}/.bashrc"
)

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║      ArchCharm Uninstall                  ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${RESET}"

read -rp "$(echo -e "${YELLOW}?${RESET} Remove all ArchCharm symlinks? [y/N] ")" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "Aborted."
    exit 0
fi

removed=0
for link in "${SYMLINKS[@]}"; do
    if [[ -L "$link" ]]; then
        rm "$link"
        success "Removed symlink: ${link}"
        ((removed++))
    elif [[ -e "$link" ]]; then
        warn "Not a symlink, skipping: ${link}"
    fi
done

echo ""
info "Removed ${removed} symlinks."

# Remove helper scripts
if [[ -f "${HOME}/.local/bin/sync-niri-theme.sh" ]]; then
    rm "${HOME}/.local/bin/sync-niri-theme.sh"
    success "Removed: ~/.local/bin/sync-niri-theme.sh"
fi

echo -e "  ${YELLOW}Backups (if any) are in:${RESET} ~/.config/archcharm-backup-*"
echo ""
