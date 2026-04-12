#!/bin/sh
# Ensures noctalia.kdl has border, focus-ring, and shadow enabled
# after Noctalia theme change regenerates the file.
#
# Noctalia's built-in niri template generates colors but omits
# "on" and "width" directives. This script patches them in.

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
