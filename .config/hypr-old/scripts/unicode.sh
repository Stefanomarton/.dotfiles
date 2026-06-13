#!/usr/bin/env bash

# Path to your file
UNICODE_FILE="/home/sm/projects/programming/bash/unicode-char"

# Prompt using tofi
SELECTION=$(cat "$UNICODE_FILE" | tofi)

# Exit if nothing selected
[ -z "$SELECTION" ] && exit

# Extract the first character (Unicode symbol)
CHAR=$(echo "$SELECTION" | awk '{print $1}')

# Copy to clipboard (Wayland)
echo -n "$CHAR" | wl-copy

# Optional: Type the character directly (uncomment if needed)
wtype "$CHAR"

# Notify (optional)
# notify-send "Unicode character copied" "'$CHAR' has been copied to the clipboard"
