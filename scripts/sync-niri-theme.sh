#!/bin/sh
# Applies Noctalia theme colors to all configured apps after theme change.
# Runs automatically via Noctalia's colorGeneration hook.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/apply-theme.sh"

FILE="$HOME/.config/niri/noctalia.kdl"
[ -f "$FILE" ] || exit 0

perl -i -0777 -pe '
    # Add "on\n        width 2" after "focus-ring {" if not already there
    s/(focus-ring \{)\n(?!\s*on\n)/$1\n        on\n        width 2\n/g;

    # Add "on\n        width 2" after "border {" if not already there
    s/(border \{)\n(?!\s*on\n)/$1\n        on\n        width 2\n/g;

    # Replace simple shadow block with full one
    s/shadow \{\n\s*color ([^\n]+)\n\s*\}/shadow {\n        on\n        color $1\n        softness 25\n        spread 3\n        offset x=0 y=4\n    }/g;
' "$FILE"

# Reload niri to apply new colors
niri msg action do-screen-transition 2>/dev/null || true
