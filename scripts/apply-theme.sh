#!/usr/bin/env bash
# Noctalia Theme Engine - apply-theme.sh
# Applies colors from colors.json to all template files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLORS_JSON="$PROJECT_ROOT/dotfiles/noctalia/colors.json"

if [[ ! -f "$COLORS_JSON" ]]; then
    echo "Error: colors.json not found at $COLORS_JSON"
    exit 1
fi

# Load color keys using jq
mapfile -t color_keys < <(jq -r 'keys[]' "$COLORS_JSON")

# Function to apply colors to a single template
apply_template() {
    local template="$1"
    local output="$2"
    local content
    content=$(cat "$template")

    for key in "${color_keys[@]}"; do
        local value
        value=$(jq -r ".$key" "$COLORS_JSON")
        # Replace {{key}} with value (case sensitive, exact match)
        # Using string replacement instead of sed to avoid escaping issues with hex codes
        content="${content//\{\{$key\}\}/$value}"
        # Also handle {{key.hex}} if any (common in some configs)
        content="${content//\{\{$key.hex\}\}/$value}"
    done

    # Strip # for cases that need hex only (e.g. some CSS or specialized configs)
    for key in "${color_keys[@]}"; do
        local value
        value=$(jq -r ".$key" "$COLORS_JSON")
        local hex_only="${value#\#}"
        content="${content//\{\{$key.hex_only\}\}/$hex_only}"
    done

    echo "$content" > "$output"
    echo "Applied: $(basename "$template") -> $(basename "$output")"
}

# Define templates to process
# Format: "template_path|output_path"
TEMPLATES=(
    "$PROJECT_ROOT/dotfiles/niri/noctalia.kdl.template|$PROJECT_ROOT/dotfiles/niri/noctalia.kdl"
    "$PROJECT_ROOT/dotfiles/alacritty/themes/noctalia.toml.template|$PROJECT_ROOT/dotfiles/alacritty/themes/noctalia.toml"
    "$PROJECT_ROOT/dotfiles/fuzzel/themes/noctalia.template|$PROJECT_ROOT/dotfiles/fuzzel/themes/noctalia"
    "$PROJECT_ROOT/dotfiles/noctalia/vscode-theme.json.template|$PROJECT_ROOT/dotfiles/noctalia/vscode-theme.json"
)

# Home config mappings
if [[ -d "$HOME/.config/niri" ]]; then
    TEMPLATES+=("$PROJECT_ROOT/dotfiles/niri/noctalia.kdl.template|$HOME/.config/niri/noctalia.kdl")
fi
if [[ -d "$HOME/.config/alacritty/themes" ]]; then
    TEMPLATES+=("$PROJECT_ROOT/dotfiles/alacritty/themes/noctalia.toml.template|$HOME/.config/alacritty/themes/noctalia.toml")
fi
if [[ -d "$HOME/.config/fuzzel/themes" ]]; then
    TEMPLATES+=("$PROJECT_ROOT/dotfiles/fuzzel/themes/noctalia.template|$HOME/.config/fuzzel/themes/noctalia")
fi

for entry in "${TEMPLATES[@]}"; do
    IFS="|" read -r template output <<< "$entry"
    if [[ -f "$template" ]]; then
        mkdir -p "$(dirname "$output")"
        apply_template "$template" "$output"
    fi
done

# Signal apps to reload if running
if command -v niri >/dev/null; then
    niri msg action do-screen-transition 2>/dev/null || true
fi

echo "Noctalia theme applied successfully!"
