#!/bin/bash
VAL="$1"
VARS="$HOME/.config/caelestia/hypr-vars.lua"

if grep -q "windowOpacity" "$VARS"; then
    sed -i "s/windowOpacity[[:space:]]*=[[:space:]]*[0-9.]*,/windowOpacity = $VAL,/" "$VARS"
else
    sed -i "s/^return {/return {\n    windowOpacity = $VAL,/" "$VARS"
fi

hyprctl reload
