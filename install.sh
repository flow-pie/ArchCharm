#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  ArchCharm - Professional Arch Linux Dotfiles                  ║
# ║  A cohesive, opinionated desktop environment built on Niri      ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
readonly INSTALLERS_DIR="${SCRIPT_DIR}/installers"
readonly LOG_FILE="/tmp/archcharm-install-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config/archcharm-backup-$(date +%Y%m%d-%H%M%S)"

# ── Colors ─────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# ── Logging ────────────────────────────────────────────────────────
log() { echo -e "${DIM}[$(date +%H:%M:%S)]${RESET} $*" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[INFO]${RESET} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[✓]${RESET} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[✗]${RESET} $*" | tee -a "$LOG_FILE"; }
header() {
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════${RESET}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}  $*${RESET}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${RESET}\n" | tee -a "$LOG_FILE"
}

# ── Helpers ────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

backup_file() {
    local file="$1"
    if [[ -e "$file" ]]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        cp -r "$file" "$BACKUP_DIR/$(dirname "$file")/" 2>/dev/null || true
        log "Backed up: ${file}"
    fi
}

link_file() {
    local src="$1" dest="$2"
    backup_file "$dest"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    success "Linked: ${dest}"
}

confirm() {
    local prompt="$1"
    if [[ "${ARCHCHARM_YES:-}" == "1" ]]; then return 0; fi
    read -rp "$(echo -e "${YELLOW}?${RESET} ${prompt} [Y/n] ")" answer
    [[ "${answer:-Y}" =~ ^[Yy]$ ]]
}

# ── Preflight ──────────────────────────────────────────────────────
preflight() {
    header "Preflight Checks"

    # Must be on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        error "This script is designed for Arch Linux only."
        exit 1
    fi
    success "Running on Arch Linux"

    # Must not be root
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root."
        exit 1
    fi
    success "Running as non-root user: $(whoami)"

    # Check for AUR helper
    if command_exists yay; then
        AUR_HELPER="yay"
    elif command_exists paru; then
        AUR_HELPER="paru"
    else
        warn "No AUR helper found. Installing yay..."
        install_yay
    fi
    success "AUR helper: ${AUR_HELPER}"

    # Ensure sudo access
    if ! sudo -v 2>/dev/null; then
        error "This script requires sudo access."
        exit 1
    fi
    success "Sudo access confirmed"
}

install_yay() {
    info "Installing yay from source..."
    sudo pacman -S --needed --noconfirm git base-devel
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    AUR_HELPER="yay"
    success "yay installed"
}

# ── Package Installation ──────────────────────────────────────────
install_packages() {
    header "Installing Packages"

    local pacman_pkgs=()
    local aur_pkgs=()

    # Read package lists
    if [[ -f "${SCRIPT_DIR}/packages-pacman.txt" ]]; then
        mapfile -t pacman_pkgs < <(grep -v '^#\|^$' "${SCRIPT_DIR}/packages-pacman.txt")
    fi
    if [[ -f "${SCRIPT_DIR}/packages-aur.txt" ]]; then
        mapfile -t aur_pkgs < <(grep -v '^#\|^$' "${SCRIPT_DIR}/packages-aur.txt")
    fi

    # Official repos
    if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
        info "Installing ${#pacman_pkgs[@]} packages from official repos..."
        sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}" 2>&1 | tee -a "$LOG_FILE"
        success "Official packages installed"
    fi

    # AUR
    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        info "Installing ${#aur_pkgs[@]} packages from AUR..."
        $AUR_HELPER -S --needed --noconfirm "${aur_pkgs[@]}" 2>&1 | tee -a "$LOG_FILE"
        success "AUR packages installed"
    fi
}

# ── Dotfiles Deployment ────────────────────────────────────────────
deploy_dotfiles() {
    header "Deploying Configuration Files"

    local config_dir="${HOME}/.config"
    local home_dir="${HOME}"

    # Niri
    info "Deploying Niri config..."
    link_file "${DOTFILES_DIR}/niri" "${config_dir}/niri"

    # Fish Shell
    info "Deploying Fish shell config..."
    link_file "${DOTFILES_DIR}/fish" "${config_dir}/fish"

    # Terminals
    info "Deploying terminal configs..."
    link_file "${DOTFILES_DIR}/alacritty" "${config_dir}/alacritty"
    link_file "${DOTFILES_DIR}/kitty" "${config_dir}/kitty"
    link_file "${DOTFILES_DIR}/foot" "${config_dir}/foot"

    # Neovim
    info "Deploying Neovim config..."
    link_file "${DOTFILES_DIR}/nvim" "${config_dir}/nvim"

    # Noctalia
    info "Deploying Noctalia shell config..."
    link_file "${DOTFILES_DIR}/noctalia" "${config_dir}/noctalia"

    # Application configs
    info "Deploying application configs..."
    link_file "${DOTFILES_DIR}/fuzzel" "${config_dir}/fuzzel"
    link_file "${DOTFILES_DIR}/swaylock" "${config_dir}/swaylock"
    link_file "${DOTFILES_DIR}/wlogout" "${config_dir}/wlogout"
    link_file "${DOTFILES_DIR}/cava" "${config_dir}/cava"
    link_file "${DOTFILES_DIR}/lazygit" "${config_dir}/lazygit"
    link_file "${DOTFILES_DIR}/bottom" "${config_dir}/bottom"
    link_file "${DOTFILES_DIR}/tmux" "${config_dir}/tmux"
    link_file "${DOTFILES_DIR}/mpv" "${config_dir}/mpv"
    link_file "${DOTFILES_DIR}/yazi" "${config_dir}/yazi"
    link_file "${DOTFILES_DIR}/ranger" "${config_dir}/ranger"
    link_file "${DOTFILES_DIR}/fastfetch" "${config_dir}/fastfetch"
    link_file "${DOTFILES_DIR}/walker" "${config_dir}/walker"

    # Starship prompt
    link_file "${DOTFILES_DIR}/starship/starship.toml" "${config_dir}/prompt/starship.toml"

    # Scripts
    info "Installing helper scripts..."
    mkdir -p "${home_dir}/.local/bin"
    if [[ -f "${SCRIPT_DIR}/scripts/sync-niri-theme.sh" ]]; then
        cp "${SCRIPT_DIR}/scripts/sync-niri-theme.sh" "${home_dir}/.local/bin/sync-niri-theme.sh"
        chmod +x "${home_dir}/.local/bin/sync-niri-theme.sh"
        success "Installed sync-niri-theme.sh to ~/.local/bin/"
    fi

    # Home directory files
    info "Deploying home directory configs..."
    if [[ -f "${DOTFILES_DIR}/bashrc" ]]; then
        link_file "${DOTFILES_DIR}/bashrc" "${home_dir}/.bashrc"
    fi

    # MIME associations
    if [[ -f "${DOTFILES_DIR}/mimeapps.list" ]]; then
        link_file "${DOTFILES_DIR}/mimeapps.list" "${config_dir}/mimeapps.list"
    fi

    success "All dotfiles deployed"
}

# ── Services ───────────────────────────────────────────────────────
enable_services() {
    header "Enabling Services"

    # Enable greetd for Niri session (if installed)
    if systemctl list-unit-files greetd.service &>/dev/null; then
        info "Enabling greetd login manager..."
        sudo systemctl enable greetd.service
        success "greetd enabled"
    fi

    # Enable Bluetooth
    if systemctl list-unit-files bluetooth.service &>/dev/null; then
        info "Enabling Bluetooth..."
        sudo systemctl enable bluetooth.service
        success "Bluetooth enabled"
    fi

    # Enable NetworkManager
    if systemctl list-unit-files NetworkManager.service &>/dev/null; then
        sudo systemctl enable NetworkManager.service
        success "NetworkManager enabled"
    fi
}

# ── Shell Setup ────────────────────────────────────────────────────
setup_shell() {
    header "Configuring Default Shell"

    if command_exists fish; then
        if [[ "$SHELL" != *"fish"* ]]; then
            if confirm "Set Fish as your default shell?"; then
                chsh -s "$(which fish)"
                success "Default shell set to Fish"
            fi
        else
            success "Fish is already the default shell"
        fi
    fi
}

# ── Fisher Plugins ─────────────────────────────────────────────────
install_fisher() {
    header "Installing Fisher Plugins"

    if command_exists fish; then
        info "Installing Fisher and plugins..."
        fish -c '
            if not functions -q fisher
                curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
                fisher install jorgebucaran/fisher
            end
            fisher install jorgebucaran/nvm.fish
        ' 2>&1 | tee -a "$LOG_FILE"
        success "Fisher plugins installed"
    else
        warn "Fish shell not found, skipping Fisher setup"
    fi
}

# ── Fonts ──────────────────────────────────────────────────────────
install_fonts() {
    header "Installing Fonts"

    local font_pkgs=(
        "ttf-jetbrains-mono-nerd"
        "ttf-maple"
        "ttf-fira-code"
        "noto-fonts"
        "noto-fonts-emoji"
        "ttf-roboto-mono"
    )

    info "Installing Nerd Fonts and typefaces..."
    sudo pacman -S --needed --noconfirm "${font_pkgs[@]}" 2>&1 | tee -a "$LOG_FILE" ||
        $AUR_HELPER -S --needed --noconfirm "${font_pkgs[@]}" 2>&1 | tee -a "$LOG_FILE"

    fc-cache -fv &>/dev/null
    success "Fonts installed and cache refreshed"
}

# ── Post Install ───────────────────────────────────────────────────
post_install() {
    header "Post-Installation"

    echo ""
    echo -e "${GREEN}${BOLD}  ╔═══════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}  ║     ArchCharm Installation Complete!      ║${RESET}"
    echo -e "${GREEN}${BOLD}  ╚═══════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${CYAN}Log file:${RESET}     ${LOG_FILE}"
    echo -e "  ${CYAN}Backups:${RESET}      ${BACKUP_DIR}"
    echo ""
    echo -e "  ${YELLOW}Next steps:${RESET}"
    echo -e "    1. Reboot your system:     ${BOLD}sudo reboot${RESET}"
    echo -e "    2. Select Niri session at login"
    echo -e "    3. Press ${BOLD}Mod+Shift+/?${RESET} for keybinding help"
    echo ""
    echo -e "  ${DIM}Customize your setup: ~/.config/niri/config.kdl${RESET}"
    echo -e "  ${DIM}Change wallpaper:     Noctalia Settings > Wallpaper${RESET}"
    echo ""
}

# ── Usage ──────────────────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}ArchCharm${RESET} - Arch Linux Dotfiles

${BOLD}Usage:${RESET}
  ./install.sh [options]

${BOLD}Options:${RESET}
  -a, --all          Full installation (packages + dotfiles + services)
  -d, --dotfiles     Deploy dotfiles only (no package installation)
  -p, --packages     Install packages only (no dotfile deployment)
  -s, --services     Enable services only
  -f, --fonts        Install fonts only
  -y, --yes          Skip all confirmation prompts
  -h, --help         Show this help message

${BOLD}Environment:${RESET}
  ARCHCHARM_YES=1    Skip all confirmations (same as -y)

${BOLD}Examples:${RESET}
  ./install.sh --all             # Full install
  ./install.sh --dotfiles -y     # Deploy dotfiles without prompts
  ARCHCHARM_YES=1 ./install.sh   # Full unattended install

EOF
}

# ── Main ───────────────────────────────────────────────────────────
main() {
    local do_all=false
    local do_dotfiles=false
    local do_packages=false
    local do_services=false
    local do_fonts=false

    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -a | --all) do_all=true ;;
        -d | --dotfiles) do_dotfiles=true ;;
        -p | --packages) do_packages=true ;;
        -s | --services) do_services=true ;;
        -f | --fonts) do_fonts=true ;;
        -y | --yes) export ARCHCHARM_YES=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        esac
        shift
    done

    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║            A R C H C H A R M              ║"
    echo "  ║   Professional Arch Linux Dotfiles        ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${RESET}"

    preflight

    if $do_all; then
        install_fonts
        install_packages
        deploy_dotfiles
        install_fisher
        enable_services
        setup_shell
    else
        $do_fonts && install_fonts
        $do_packages && install_packages
        $do_dotfiles && deploy_dotfiles
        $do_dotfiles && install_fisher
        $do_services && enable_services
        $do_dotfiles && setup_shell
    fi

    post_install
}

main "$@"
