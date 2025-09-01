#!/usr/bin/env bash
# change-display.sh - Configure Samsung Odyssey G9 on Mac Pro 6,1 (R9 270X)

set -e

# Get first connected display (e.g., DisplayPort-9)
DISPLAY_NAME=$(xrandr --query | grep " connected" | head -n1 | cut -d' ' -f1)
echo "Using display: $DISPLAY_NAME"

apply_mode() {
    local WIDTH=$1
    local HEIGHT=$2
    local RATE=$3

    echo "Generating mode for ${WIDTH}x${HEIGHT} @ ${RATE}Hz..."
    local CVT_OUT
    if ! CVT_OUT=$(cvt -r "$WIDTH" "$HEIGHT" "$RATE" 2>/dev/null | grep "Modeline"); then
        echo "❌ cvt failed for ${WIDTH}x${HEIGHT}@${RATE}"
        return 1
    fi

    # Extract name and numbers
    local NAME
    NAME=$(echo "$CVT_OUT" | awk '{print $2}' | tr -d '"')
    local LINE
    LINE=$(echo "$CVT_OUT" | cut -d' ' -f3-)

    if ! xrandr | grep -q "$NAME"; then
        echo "Adding mode $NAME"
        eval xrandr --newmode "$NAME" "$LINE"
        xrandr --addmode "$DISPLAY_NAME" "$NAME" || return 1
    fi

    echo "Trying mode $NAME..."
    if xrandr --output "$DISPLAY_NAME" --mode "$NAME"; then
        echo "✅ Success: ${WIDTH}x${HEIGHT}@${RATE}"
        return 0
    else
        echo "❌ Failed: ${WIDTH}x${HEIGHT}@${RATE}"
        return 1
    fi
}


if apply_mode 3840 1080 60; then
    echo "Scaling to fill screen..."
    xrandr --output "DisplayPort-9" --scale 1.3333x1.3333
    exit 0
fi

# # Try native 5120x1440 at different refresh rates
# for RATE in 120 100 60; do
#     if apply_mode 5120 1440 $RATE; then
#         exit 0
#     fi
# done

# Fallback: 3840x1080 @ 60Hz
echo "Falling back to 3840x1080..."
if apply_mode 3840 1080 60; then
    echo "Scaling to 32:9 ratio as fallback..."
    xrandr --output "$DISPLAY_NAME" --scale 1.3333x1.3333
    exit 0
fi

echo "❌ Could not configure Odyssey G9"
exit 1
