#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  ArchCharm - Arch Linux Dotfiles
#  A cohesive, opinionated desktop environment built on Niri
# ═══════════════════════════════════════════════════════════════════════
set -o pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
readonly LOG_FILE="/tmp/archcharm-install-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="${HOME}/.config/archcharm-backup-$(date +%Y%m%d-%H%M%S)"

CURRENT_STEP=0
TOTAL_STEPS=0
AUR_HELPER="yay"

# ═══════════════════════════════════════════════════════════════════════
#  COLORS & STYLING - Nord-inspired palette
# ═══════════════════════════════════════════════════════════════════════
readonly NORD0='\033[0;30m'    # Darkest
readonly NORD1='\033[0;34m'    # Darker blue
readonly NORD2='\033[0;35m'    # Purple
readonly NORD3='\033[0;36m'    # Cyan
readonly NORD4='\033[0;37m'    # Light gray
readonly NORD5='\033[0;38m'    # Lighter
readonly NORD6='\033[0;39m'    # Lightest
readonly NORD7='\033[0;40m'    # Green bg
readonly NORD8='\033[0;41m'    # Red bg
readonly NORD9='\033[0;42m'    # Yellow bg
readonly NORD10='\033[0;43m'   # Blue bg

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;95m'
readonly ORANGE='\033[0;38;5;208m'
readonly LAVENDER='\033[0;38;5;147m'
readonly TEAL='\033[0;38;5;30m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly LIGHT_GRAY='\033[0;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

readonly MAIN_COLOR="$CYAN"
readonly ACCENT_COLOR="$GREEN"
readonly BG_COLOR="$NORD0"
readonly SEC_BG='\033[48;5;18m'
readonly SEC_BG_LIGHT='\033[48;5;235m'

readonly MESSAGE_COLOR="${LIGHT_GRAY}"
readonly MESSAGE_PADDING="                             "

SPINNER_CHARS=('⠋' '⠙' '⠸' '⠴' '⠦' '⠇' '⠏' '⠧')

# TUI box drawing characters
readonly BOX_TOP_LEFT='┌'
readonly BOX_TOP_RIGHT='┐'
readonly BOX_BOTTOM_LEFT='└'
readonly BOX_BOTTOM_RIGHT='┘'
readonly BOX_HORIZONTAL='─'
readonly BOX_VERTICAL='│'
readonly BOX_T_DOWN='┬'
readonly BOX_T_UP='┴'
readonly BOX_T_RIGHT='├'
readonly BOX_T_LEFT='┤'

# ═══════════════════════════════════════════════════════════════════════
#  LOGGING
# ═══════════════════════════════════════════════════════════════════════
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════
#  PROGRESS BAR
# ═══════════════════════════════════════════════════════════════════════
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local FILLED=$((PERCENT / 5))
    local EMPTY=$((20 - FILLED))

    local BAR=""
    for ((i=0; i<FILLED; i++)); do 
        if (( i < 5 )); then BAR+="${GREEN}█";
        elif (( i < 10 )); then BAR+="${CYAN}█";
        elif (( i < 15 )); then BAR+="${LAVENDER}█";
        else BAR+="${TEAL}█";
        fi
    done
    for ((i=0; i<EMPTY; i++)); do BAR+="${GRAY}░"; done
    BAR+="${NC}"

    echo ""
    printf "${SEC_BG_LIGHT}                                                              ${NC}"
    printf "\n${SEC_BG_LIGHT} ${WHITE}❯ ${MAIN_COLOR}Step${WHITE} ${CURRENT_STEP}${MAIN_COLOR}/${TOTAL_STEPS}${WHITE}  ${BAR} ${WHITE}${PERCENT}%%${NC}"
    printf "\n${SEC_BG_LIGHT}                                                              ${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#  SPINNER
# ═══════════════════════════════════════════════════════════════════════
spinner() {
    local pid=$1
    local message=$2
    local i=0
    local spinstr=""

    while kill -0 "$pid" 2>/dev/null; do
        spinstr="${CYAN}${SPINNER_CHARS[$i]}${NC}"
        printf "\r  ${spinstr} ${MESSAGE_COLOR}▌${MESSAGE_COLOR}%s "${NC}" "$message"  "
        i=$(( (i + 1) % ${#SPINNER_CHARS[@]} ))
        sleep 0.08
    done

    wait "$pid"
    local exit_code=$?

    if [ "$exit_code" -eq 0 ]; then
        # Right-aligned checkmark with left-padded message
        printf "\r  ${GREEN}✓${NC} %s\n" "$MESSAGE_PADDING$message"
        printf "  ${GREEN}✓${NC} %bDone${NC}\n" "$MESSAGE_PADDING"
        log "OK: $message"
    else
        printf "\r  ${RED}✗${NC} %s\n" "$MESSAGE_PADDING$message"
        printf "  ${RED}✗${NC} %bFailed — Check ${LOG_FILE}${NC}\n" "$MESSAGE_PADDING"
        log "FAILED: $message"
    fi

    return "$exit_code"
}

# ═══════════════════════════════════════════════════════════════════════
#  LOGGING FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════
info() { echo -e "${TEAL}  ◈${NC} ${LIGHT_GRAY}$*"; log "INFO: $*"; }
success() { echo -e "${GREEN}  ✓${NC} ${WHITE}$*"; log "OK: $*"; }
warn() { echo -e "${ORANGE}  !${NC} ${LIGHT_GRAY}$*"; log "WARN: $*"; }
error() { echo -e "${RED}  ✗${NC} ${LIGHT_GRAY}$*"; log "ERROR: $*"; }

# ═══════════════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════════════
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
    
    if [[ -d "$dest" && ! -L "$dest" ]]; then
        rm -rf "$dest"
    fi
    
    ln -sf "$src" "$dest"
    success "Linked: ${dest}"
}

confirm() {
    local prompt="$1"
    if [[ "${ARCHCHARM_YES:-}" == "1" ]]; then return 0; fi
    read -rp "$(echo -e "${YELLOW}?${RESET} ${prompt} [Y/n] ")" answer
    [[ "${answer:-Y}" =~ ^[Yy]$ ]]
}

# ═══════════════════════════════════════════════════════════════════════
#  BANNER
# ═══════════════════════════════════════════════════════════════════════
show_banner() {
    clear
    local width=68
    local half=$((width / 2))
    
    # Top border with title
    echo -e "${CYAN}"
    printf "  ╔%${width}s╗\n" | tr ' ' '═'
    printf "  ║%${width}s║\n" | tr ' ' ' '
    printf "  ║  %-${((width-4))}s  ║\n" ""
    printf "  ║${BOLD}       ▄▀▄ █▀▄ █ █ █▀▀ ▄▀▄ ▀▀▄▀▀ █▀▀      ${NC}║\n"
    printf "  ║${BOLD}       █▀█ █▀▄ ▀▄▀ █▀  █▀█ █ █  █▀▀      ${NC}║\n"
    printf "  ║${BOLD}       ▀ ▀ ▀▀  ▀▀  ▀▀▀ ▀ ▀ ▀▀  ▀▀▀      ${NC}║\n"
    printf "  ║%${width}s║\n" | tr ' ' ' '
    printf "  ║${WHITE}            ${BOLD}C H A R M${NC} ${WHITE}—${NC} Arch Linux Dotfiles${NC}            ║\n"
    printf "  ║${DIM}      A cohesive desktop environment on Niri WM${NC}           ║\n"
    printf "  ║%${width}s║\n" | tr ' ' ' '
    printf "  ║  ${GRAY}Logs:${NC} ${GREEN}%-${((width-12))}s${NC}  ║\n" "$LOG_FILE"
    printf "  ║%${width}s║\n" | tr ' ' ' '
    printf "  ╚%${width}s╝\n" | tr ' ' '═'
    echo -e "${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#  SYSTEM DETECTION
# ═══════════════════════════════════════════════════════════════════════
detect_system() {
    echo -e "${PURPLE}  ◈ Detecting system information...${NC}"
    echo ""

    local os_name=$(grep -oP '^NAME=\K.*' /etc/os-release 2>/dev/null || echo "Arch Linux")
    local os_version=$(grep -oP '^VERSION=\K.*' /etc/os-release 2>/dev/null || echo "Rolling")
    local kernel=$(uname -r)
    local host=$(hostname)
    local user=$(whoami)
    local shell="${SHELL##*/}"
    local cpu_model=$(lscpu | grep 'Model name' | cut -d: -f2 | xargs || echo "Unknown")
    local mem_total=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))
    local cpu_cores=$(nproc 2>/dev/null || echo "N/A")

    # System info box
    local box_width=50
    local box_line=$(printf '─%.0s' $(seq 1 $((box_width-2))))
    echo -e "${CYAN}  ┌${NC}${box_line}${CYAN}┐${NC}"
    
    local items=(
        "  ${TEAL}▸${NC} ${WHITE}OS${NC}        ${GRAY}│${NC}  ${WHITE}${os_name}${NC}"
        "  ${TEAL}▸${NC} ${WHITE}Kernel${NC}    ${GRAY}│${NC}  ${WHITE}${kernel}${NC}"
        "  ${TEAL}▸${NC} ${WHITE}Host${NC}      ${GRAY}│${NC}  ${WHITE}${host}${NC}"
        "  ${TEAL}▸${NC} ${WHITE}User${NC}      ${GRAY}│${NC}  ${WHITE}${user}${NC}"
        "  ${TEAL}▸${NC} ${WHITE}Shell${NC}     ${GRAY}│${NC}  ${WHITE}${shell}${NC}"
        "  ${TEAL}▸${NC} ${WHITE}CPU${NC}       ${GRAY}│${NC}  ${WHITE}${cpu_model} (${cpu_cores} cores)${NC}"
        "  ${TEAL}▸${NC} ${WHITE}RAM${NC}       ${GRAY}│${NC}  ${WHITE}${mem_total} MB${NC}"
    )
    
    for item in "${items[@]}"; do
        printf "${CYAN}  │${NC}%-${((box_width-2))}s${CYAN}│${NC}\n" "$item"
    done
    
    echo -e "${CYAN}  └${NC}$(printf '─%.0s' $(seq 1 $((box_width-2))))${CYAN}┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALLATION OPTIONS
# ═══════════════════════════════════════════════════════════════════════
show_options() {
    echo -e "${CYAN}  ◈ Choose installation type:${NC}"
    echo ""
    
    # Option box
    local opt_width=62
    echo -e "${CYAN}  ┌${NC}$(printf '─%.0s' $(seq 1 $((opt_width-2))))${CYAN}┐${NC}"
    printf "${CYAN}  │${NC}  ${BOLD}${WHITE}Option${NC}                    ${WHITE}Description${NC}                            ${CYAN}│${NC}\n"
    echo -e "${CYAN}  ├${NC}$(printf '─%.0s' $(seq 1 $((opt_width-2))))${CYAN}┴${NC}"
    
    local options=(
        "  ${GREEN}1${NC}  ${WHITE}Full Install${NC}       Fonts + Packages + Dotfiles + Services"
        "  ${WHITE}2  ${CYAN}Fonts${NC}              ${CYAN}Install Nerd Fonts and typefaces only${NC}"
        "  ${WHITE}3  ${CYAN}Packages${NC}           ${CYAN}Install system packages only${NC}"
        "  ${WHITE}4  ${CYAN}Dotfiles${NC}           ${CYAN}Deploy configuration files only${NC}"
        "  ${WHITE}5  ${CYAN}Services${NC}           ${CYAN}Enable system services only${NC}"
        "  ${WHITE}6  ${CYAN}Custom${NC}              ${CYAN}Choose specific components${NC}"
    )
    
    for opt in "${options[@]}"; do
        printf "${CYAN}  │${NC} %-${((opt_width-4))}s${CYAN}│${NC}\n" "$opt"
    done
    
    echo -e "${CYAN}  └${NC}$(printf '─%.0s' $(seq 1 $((opt_width-2))))${CYAN}┘${NC}"
    echo ""

    while true; do
        read -rp "  ${WHITE}Enter number (1-6)${NC} [${GREEN}default: 1${NC}]: " opt_input
        opt_input=${opt_input:-1}
        if [[ "$opt_input" =~ ^[1-6]$ ]]; then
            break
        else
            echo -e "  ${RED}Invalid — enter 1, 2, 3, 4, 5, or 6.${NC}"
        fi
    done

    case $opt_input in
        1) 
            INSTALL_TYPE="full"
            TOTAL_STEPS=7
            ;;
        2) 
            INSTALL_TYPE="fonts"
            TOTAL_STEPS=1
            ;;
        3) 
            INSTALL_TYPE="packages"
            TOTAL_STEPS=1
            ;;
        4) 
            INSTALL_TYPE="dotfiles"
            TOTAL_STEPS=2
            ;;
        5) 
            INSTALL_TYPE="services"
            TOTAL_STEPS=1
            ;;
        6) 
            INSTALL_TYPE="custom"
            TOTAL_STEPS=0
            show_custom_options
            ;;
    esac

    echo -e "\n  ${GREEN}✓ Selected: ${BOLD}${INSTALL_TYPE}${NC}"
    log "INSTALL_TYPE=$INSTALL_TYPE"
    sleep 0.3
}

INSTALL_FONTS=false
INSTALL_PACKAGES=false
INSTALL_DOTFILES=false
INSTALL_SERVICES=false

show_custom_options() {
    echo ""
    echo -e "${CYAN}Select components to install:${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} Fonts         $([[ "$INSTALL_FONTS" == "true" ]] && echo "${GREEN}✓${NC}" || echo " ")  Install Nerd Fonts"
    echo -e "  ${WHITE}2)${NC} Packages      $([[ "$INSTALL_PACKAGES" == "true" ]] && echo "${GREEN}✓${NC}" || echo " ")  Install system packages"
    echo -e "  ${WHITE}3)${NC} Dotfiles      $([[ "$INSTALL_DOTFILES" == "true" ]] && echo "${GREEN}✓${NC}" || echo " ")  Deploy dotfiles"
    echo -e "  ${WHITE}4)${NC} Services      $([[ "$INSTALL_SERVICES" == "true" ]] && echo "${GREEN}✓${NC}" || echo " ")  Enable system services"
    echo ""
    echo -e "  ${GREEN}D)${NC} Done — Start installation"
    echo ""

    while true; do
        read -rp "  Toggle option (1-4), D to done: " cust_input
        case "$cust_input" in
            1) INSTALL_FONTS=$([ "$INSTALL_FONTS" == "true" ] && echo "false" || echo "true");;
            2) INSTALL_PACKAGES=$([ "$INSTALL_PACKAGES" == "true" ] && echo "false" || echo "true");;
            3) INSTALL_DOTFILES=$([ "$INSTALL_DOTFILES" == "true" ] && echo "false" || echo "true");;
            4) INSTALL_SERVICES=$([ "$INSTALL_SERVICES" == "true" ] && echo "false" || echo "true");;
            d|D) 
                if ! $INSTALL_FONTS && ! $INSTALL_PACKAGES && ! $INSTALL_DOTFILES && ! $INSTALL_SERVICES; then
                    echo -e "  ${RED}Select at least one option!${NC}"
                    continue
                fi
                break
                ;;
            *) echo -e "  ${RED}Invalid option.${NC}";;
        esac
    done

    $INSTALL_FONTS && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    $INSTALL_PACKAGES && TOTAL_STEPS=$((TOTAL_STEPS + 1))
    $INSTALL_DOTFILES && TOTAL_STEPS=$((TOTAL_STEPS + 2))
    $INSTALL_SERVICES && TOTAL_STEPS=$((TOTAL_STEPS + 1))
}

# ═══════════════════════════════════════════════════════════════════════
#  PREFLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════════════
preflight() {
    update_progress
    echo -e "${PURPLE}  ◈ Running preflight checks...${NC}"
    echo ""

    # Check for Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        echo -e "  ${RED}✗${NC}  This script is designed for Arch Linux only."
        exit 1
    fi
    printf "  ${GREEN}✓${NC} ${WHITE}Running on Arch Linux${NC}\n"

    # Check not running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "  ${RED}✗${NC}  Do not run this script as root."
        exit 1
    fi
    printf "  ${GREEN}✓${NC} ${WHITE}Running as non-root user${NC}: ${CYAN}$(whoami)${NC}\n"

    # Check for AUR helper
    if command_exists yay; then
        AUR_HELPER="yay"
    elif command_exists paru; then
        AUR_HELPER="paru"
    else
        echo -e "  ${ORANGE}!${NC}  No AUR helper found. Installing yay..."
        (install_yay &) && spinner $! "Installing yay AUR helper..." || true
    fi
    printf "  ${GREEN}✓${NC} ${WHITE}AUR helper${NC}: ${GREEN}${AUR_HELPER}${NC}\n"

    # Check sudo access
    if ! sudo -v 2>/dev/null; then
        echo -e "  ${RED}✗${NC}  This script requires sudo access."
        exit 1
    fi
    printf "  ${GREEN}✓${NC} ${WHITE}Sudo access confirmed${NC}\n"
    echo ""

    log "=== Preflight complete ==="
}

install_yay() {
    sudo pacman -S --needed --noconfirm git base-devel
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    AUR_HELPER="yay"
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALL FONTS
# ═══════════════════════════════════════════════════════════════════════
step_fonts() {
    update_progress
    echo -e "${PURPLE}  ◈ Installing fonts...${NC}"
    echo ""

    local font_pkgs=(
        "ttf-jetbrains-mono-nerd"
        "ttf-maple-font"
        "ttf-fira-code"
        "noto-fonts"
        "noto-fonts-emoji"
        "ttf-roboto-mono"
    )

    local confirm_flag=""
    if [[ "${ARCHCHARM_YES:-}" == "1" ]]; then
        confirm_flag="--noconfirm"
    fi

    for pkg in "${font_pkgs[@]}"; do
        if dpkg -s "${pkg}" &>/dev/null || pacman -Q "${pkg}" &>/dev/null; then
            printf "  ${GRAY}≈${NC} ${WHITE}%-25s ${DIM}already installed${NC}\n" "${pkg}"
        else
            (sudo pacman -S --needed $confirm_flag "$pkg" >> "$LOG_FILE" 2>&1) &
            spinner $! "Installing ${pkg}..."
        fi
    done

    fc-cache -fv &>/dev/null
    success "Fonts installed"
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALL PACKAGES
# ═══════════════════════════════════════════════════════════════════════
step_packages() {
    update_progress
    echo -e "${PURPLE}  ◈ Installing packages...${NC}"
    echo ""

    local pacman_pkgs=()
    local aur_pkgs=()
    
    if [[ -f "${SCRIPT_DIR}/packages-pacman.txt" ]]; then
        mapfile -t pacman_pkgs < <(grep -v '^#\|^$' "${SCRIPT_DIR}/packages-pacman.txt")
    fi
    if [[ -f "${SCRIPT_DIR}/packages-aur.txt" ]]; then
        mapfile -t aur_pkgs < <(grep -v '^#\|^$' "${SCRIPT_DIR}/packages-aur.txt")
    fi

    local confirm_flag=""
    if [[ "${ARCHCHARM_YES:-}" == "1" ]]; then
        confirm_flag="--noconfirm"
    fi

    if [[ ${#pacman_pkgs[@]} -gt 0 ]]; then
        echo -e "  ${TEAL}▸${NC} ${WHITE}Installing${NC} ${#pacman_pkgs[@]} packages from official repos..."
        (sudo pacman -S --needed $confirm_flag "${pacman_pkgs[@]}" >> "$LOG_FILE" 2>&1) &
        spinner $! "Installing official packages..."
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        echo -e "  ${TEAL}▸${NC} ${WHITE}Installing${NC} ${#aur_pkgs[@]} packages from AUR..."
        ($AUR_HELPER -S --needed $confirm_flag "${aur_pkgs[@]}" >> "$LOG_FILE" 2>&1) &
        spinner $! "Installing AUR packages..."
    fi

    success "Packages installed"
}

# ═══════════════════════════════════════════════════════════════════════
#  DEPLOY DOTFILES
# ═══════════════════════════════════════════════════════════════════════
step_dotfiles() {
    update_progress
    echo -e "${PURPLE}  ◈ Deploying configuration files...${NC}"
    echo ""

    local config_dir="${HOME}/.config"
    local home_dir="${HOME}"

    # Core configs
    local configs=(
        "niri:${config_dir}/niri"
        "fish:${config_dir}/fish"
        "alacritty:${config_dir}/alacritty"
        "kitty:${config_dir}/kitty"
        "foot:${config_dir}/foot"
        "nvim:${config_dir}/nvim"
        "noctalia:${config_dir}/noctalia"
        "fuzzel:${config_dir}/fuzzel"
        "swaylock:${config_dir}/swaylock"
        "wlogout:${config_dir}/wlogout"
        "cava:${config_dir}/cava"
        "lazygit:${config_dir}/lazygit"
        "bottom:${config_dir}/bottom"
        "tmux:${config_dir}/tmux"
        "mpv:${config_dir}/mpv"
        "yazi:${config_dir}/yazi"
        "ranger:${config_dir}/ranger"
        "fastfetch:${config_dir}/fastfetch"
        "walker:${config_dir}/walker"
    )

    for item in "${configs[@]}"; do
        local src="${item%%:*}"
        local dest="${item##*:}"
        if [[ -d "${DOTFILES_DIR}/${src}" ]]; then
            link_file "${DOTFILES_DIR}/${src}" "${dest}"
        fi
    done

    # Starship prompt
    if [[ -d "${DOTFILES_DIR}/starship" ]]; then
        link_file "${DOTFILES_DIR}/starship" "${config_dir}/prompt"
    fi

    # Home files
    if [[ -f "${DOTFILES_DIR}/bashrc" ]]; then
        link_file "${DOTFILES_DIR}/bashrc" "${home_dir}/.bashrc"
    fi

    # MIME apps
    if [[ -f "${DOTFILES_DIR}/mimeapps.list" ]]; then
        link_file "${DOTFILES_DIR}/mimeapps.list" "${config_dir}/mimeapps.list"
    fi

    # Scripts
    mkdir -p "${home_dir}/.local/bin"
    if [[ -f "${SCRIPT_DIR}/scripts/sync-niri-theme.sh" ]]; then
        cp "${SCRIPT_DIR}/scripts/sync-niri-theme.sh" "${home_dir}/.local/bin/sync-niri-theme.sh"
        chmod +x "${home_dir}/.local/bin/sync-niri-theme.sh"
        success "Installed sync-niri-theme.sh"
    fi

    success "Dotfiles deployed"
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALL FISHER PLUGINS
# ═══════════════════════════════════════════════════════════════════════
step_fisher() {
    update_progress
    echo -e "${PURPLE}  ◈ Installing Fisher plugins...${NC}"
    echo ""

    if ! command_exists fish; then
        warn "Fish shell not found, skipping Fisher setup"
        return
    fi

    (
        fish -c '
            if not functions -q fisher
                curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
                fisher install jorgebucaran/fisher 2>/dev/null
            end
            fisher update 2>/dev/null || true
        ' >> "$LOG_FILE" 2>&1
    ) &
    spinner $! "Installing Fisher plugins..."

    success "Fisher plugins ready"
}

step_services() {
    update_progress
    echo -e "${PURPLE}  ◈ Enabling system services...${NC}"
    echo ""

    local services=("greetd" "bluetooth" "NetworkManager")
    local enabled=0

    for svc in "${services[@]}"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null; then
            if [[ "$svc" == "greetd" ]]; then
                sudo systemctl enable "${svc}.service" 2>&1 | tee -a "$LOG_FILE"
                success "Enabled ${svc}"
                ((enabled++))
            elif systemctl is-enabled "${svc}.service" &>/dev/null; then
                printf "  ${GRAY}≈${NC} ${WHITE}%-25s ${DIM}already enabled${NC}\n" "${svc}"
            else
                sudo systemctl enable "${svc}.service" 2>&1 | tee -a "$LOG_FILE"
                success "Enabled ${svc}"
                ((enabled++))
            fi
        fi
    done

    if [[ $enabled -eq 0 ]]; then
        echo -e "  ${GRAY}No services needed to be enabled.${NC}"
    fi
}

step_theme() {
    update_progress
    echo -e "${PURPLE}  ◈ Applying theme colors...${NC}"
    echo ""

    if [[ -f "${SCRIPT_DIR}/scripts/apply-theme.sh" ]]; then
        ("${SCRIPT_DIR}/scripts/apply-theme.sh" >> "$LOG_FILE" 2>&1) &
        spinner $! "Applying Noctalia theme..."
    fi

    success "Theme applied"
}

# ═══════════════════════════════════════════════════════════════════════
#  ENABLE SERVICES
# ═══════════════════════════════════════════════════════════════════════
step_services() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Enabling system services...${NC}"
    echo ""

    local services=("greetd" "bluetooth" "NetworkManager")
    local enabled=0

    for svc in "${services[@]}"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null; then
            if [[ "$svc" == "greetd" ]]; then
                sudo systemctl enable "${svc}.service" 2>&1 | tee -a "$LOG_FILE"
                success "Enabled ${svc}"
                ((enabled++))
            elif systemctl is-enabled "${svc}.service" &>/dev/null; then
                printf "  ${GRAY}~${NC}  %-60s ${GRAY}(already enabled)${NC}\n" "${svc}"
            else
                sudo systemctl enable "${svc}.service" 2>&1 | tee -a "$LOG_FILE"
                success "Enabled ${svc}"
                ((enabled++))
            fi
        fi
    done

    if [[ $enabled -eq 0 ]]; then
        echo -e "  ${GRAY}No services needed to be enabled.${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  THEME APPLICATION
# ═══════════════════════════════════════════════════════════════════════
step_theme() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Applying theme colors...${NC}"
    echo ""

    if [[ -f "${SCRIPT_DIR}/scripts/apply-theme.sh" ]]; then
        ("${SCRIPT_DIR}/scripts/apply-theme.sh" >> "$LOG_FILE" 2>&1) &
        spinner $! "Applying Noctalia theme..."
    fi

    success "Theme applied"
}

# ═══════════════════════════════════════════════════════════════════════
#  SHELL SETUP
# ═══════════════════════════════════════════════════════════════════════
setup_shell() {
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

# ═══════════════════════════════════════════════════════════════════════
#  CHECK GUM INSTALLATION
# ═══════════════════════════════════════════════════════════════════════
ensure_gum() {
    if ! command_exists gum; then
        warn "gum not found. Installing..."
        (sudo pacman -S --needed --noconfirm gum >> "$LOG_FILE" 2>&1) &
        spinner $! "Installing gum..."
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  INTERACTIVE INSTALLER
# ═══════════════════════════════════════════════════════════════════════
interactive_install() {
    ensure_gum

    clear
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "2 4" \
        "ARCHCHARM" "Professional Arch Linux Dotfiles"

    local choice
    choice=$(gum choose --no-limit "Fonts" "Packages" "Dotfiles" "Services" "All")

    if [[ -z "$choice" ]]; then
        error "No selection made."
        exit 1
    fi

    TOTAL_STEPS=7

    preflight

    [[ "$choice" == *"Fonts"* ]] || [[ "$choice" == *"All"* ]] && step_fonts
    [[ "$choice" == *"Packages"* ]] || [[ "$choice" == *"All"* ]] && step_packages
    [[ "$choice" == *"Dotfiles"* ]] || [[ "$choice" == *"All"* ]] && { step_dotfiles; step_fisher; }
    [[ "$choice" == *"Services"* ]] || [[ "$choice" == *"All"* ]] && step_services
    [[ "$choice" == *"Dotfiles"* ]] || [[ "$choice" == *"All"* ]] && { step_theme; setup_shell; }

    show_completion
}

# ═══════════════════════════════════════════════════════════════════════
#  COMPLETION
# ═══════════════════════════════════════════════════════════════════════
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'

  ╔══════════════════════════════════════════════════════════════════╗
  ║                                                                  ║
  ║                    ██████╗  ██████╗ ██████╗                       ║
  ║                    ██╔══██╗██╔═══██╗██╔══██╗                      ║
  ║                    ██████╔╝██║   ██║██████╔╝                      ║
  ║                    ██╔══██╗██║   ██║██╔══██╗                      ║
  ║                    ██║  ██║╚██████╔╝██████╔╝                      ║
  ║                    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝                       ║
  ║                                                                  ║
  ║                    I N S T A L L A T I O N                       ║
  ║                          C O M P L E T E                         ║
  ║                                                                  ║
  ╚══════════════════════════════════════════════════════════════════╝
COMPLETE
    echo -e "${NC}"
    
    # Summary box
    local sum_width=52
    local sum_line
    sum_line=$(printf '─%.0s' $(seq 1 $((sum_width-2))))
    local box_top="  ${GREEN}┌${sum_line}┐${NC}"
    local box_mid="  ${GREEN}├${sum_line}┤${NC}"
    local box_bot="  ${GREEN}└${sum_line}┘${NC}"
    
    echo -e "$box_top"
    printf "  ${GREEN}│${NC}  ${WHITE}%-46s${GREEN}│${NC}\n" "Installation Summary"
    echo -e "$box_mid"
    printf "  ${GREEN}│${NC}  ${TEAL}◈${NC} ${WHITE}Log file${NC}: ${GREEN}%-40s${GREEN}│${NC}\n" "$LOG_FILE"
    printf "  ${GREEN}│${NC}  ${TEAL}◈${NC} ${WHITE}Backups${NC} : ${GREEN}%-40s${GREEN}│${NC}\n" "$BACKUP_DIR"
    echo -e "$box_bot"
    
    echo ""
    echo -e "${YELLOW}  ┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}  │${NC}  ${BOLD}${WHITE}Next Steps:${NC}                                               ${YELLOW}│${NC}"
    echo -e "${YELLOW}  ├────────────────────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}  │${NC}                                                           ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}  ${GREEN}1.${NC} Reboot your system                                    ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}     ${CYAN}sudo reboot${NC}                                          ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}                                                           ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}  ${GREEN}2.${NC} Select Niri session at login                         ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}                                                           ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}  ${GREEN}3.${NC} Press ${WHITE}Mod+Shift+?${NC} for keybinding help                 ${YELLOW}│${NC}"
    echo -e "${YELLOW}  │${NC}                                                           ${YELLOW}│${NC}"
    echo -e "${YELLOW}  └────────────────────────────────────────────────────────┘${NC}"
    
    echo ""
    echo -e "${DIM}  Customize: ${CYAN}~/.config/niri/config.kdl${NC}"
    echo -e "${DIM}  Wallpaper: ${CYAN}Noctalia Settings > Wallpaper${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#  USAGE
# ═══════════════════════════════════════════════════════════════════════
usage() {
    cat <<EOF
${BOLD}ArchCharm${NC} - Arch Linux Dotfiles

${BOLD}Usage:${NC}
  ./install.sh [options]

${BOLD}Options:${NC}
  -i, --interactive  Interactive menu (default if no options provided)
  -a, --all          Full installation (fonts + packages + dotfiles + services)
  -d, --dotfiles     Deploy dotfiles only
  -p, --packages     Install packages only
  -s, --services     Enable services only
  -f, --fonts        Install fonts only
  -y, --yes          Skip all confirmation prompts
  -h, --help         Show this help message

${BOLD}Environment:${NC}
  ARCHCHARM_YES=1    Skip all confirmations

${BOLD}Examples:${NC}
  ./install.sh --all             # Full install
  ./install.sh --dotfiles -y     # Deploy dotfiles without prompts
  ARCHCHARM_YES=1 ./install.sh    # Unattended install

EOF
}

# ═══════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════
main() {
    local do_all=false
    local do_dotfiles=false
    local do_packages=false
    local do_services=false
    local do_fonts=false
    local interactive=false
    INSTALL_TYPE="full"
    TOTAL_STEPS=7

    if [[ $# -eq 0 ]]; then
        interactive=true
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all) do_all=true ;;
            -d|--dotfiles) do_dotfiles=true; INSTALL_TYPE="dotfiles"; TOTAL_STEPS=3 ;;
            -p|--packages) do_packages=true; INSTALL_TYPE="packages"; TOTAL_STEPS=1 ;;
            -s|--services) do_services=true; INSTALL_TYPE="services"; TOTAL_STEPS=1 ;;
            -f|--fonts) do_fonts=true; INSTALL_TYPE="fonts"; TOTAL_STEPS=1 ;;
            -i|--interactive) interactive=true ;;
            -y|--yes) export ARCHCHARM_YES=1 ;;
            -h|--help)
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

    echo "" > "$LOG_FILE"
    log "ArchCharm install started"

    if $interactive; then
        show_banner
        detect_system
        show_options
        preflight

        if [[ "$INSTALL_TYPE" == "full" ]]; then
            step_fonts
            step_packages
            step_dotfiles
            step_fisher
            step_services
            step_theme
            setup_shell
        elif [[ "$INSTALL_TYPE" == "custom" ]]; then
            $INSTALL_FONTS && step_fonts
            $INSTALL_PACKAGES && step_packages
            $INSTALL_DOTFILES && step_dotfiles
            $INSTALL_DOTFILES && step_fisher
            $INSTALL_SERVICES && step_services
            $INSTALL_DOTFILES && step_theme
            $INSTALL_DOTFILES && setup_shell
        elif [[ "$INSTALL_TYPE" == "fonts" ]]; then
            preflight
            step_fonts
        elif [[ "$INSTALL_TYPE" == "packages" ]]; then
            preflight
            step_packages
        elif [[ "$INSTALL_TYPE" == "dotfiles" ]]; then
            preflight
            step_dotfiles
            step_fisher
            step_theme
            setup_shell
        elif [[ "$INSTALL_TYPE" == "services" ]]; then
            preflight
            step_services
        fi

        show_completion
        exit 0
    fi

    echo -e "${CYAN}"
    cat << 'BANNER'
  ╔═══════════════════════════════════════════════════════════════════╗
  ║          █████╗  ██████╗███████╗██████╗ ███████╗██╗  ║        ║
  ║         ██╔══██╗██╔═══██╗██╔══╝ ██╔══██╗██║║██╗        ║
  ║         ███████║██║   ██║█████╗ ██████╔╝██║║██╗        ║
  ║         ██╔══██║██║   ██║██╔══╝ ██╔══██╗╚██╬╝         ║
  ║         ██║  ██║╚██████╔╝███████╗██║  ██║ ╚███           ║
  ║         ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝  ╚═╝         ║
  ║                      C H A R M                            ║
  ╚═══════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"

    preflight

    if $do_all; then
        step_fonts
        step_packages
        step_dotfiles
        step_fisher
        step_services
        step_theme
        setup_shell
    else
        $do_fonts && step_fonts
        $do_packages && step_packages
        $do_dotfiles && step_dotfiles
        $do_dotfiles && step_fisher
        $do_services && step_services
        $do_dotfiles && step_theme
    fi

    show_completion
}

main "$@"
