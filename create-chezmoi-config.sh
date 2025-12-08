#!/bin/bash

# -----------------------------------------------------------------------------
# RUN_ONCE: Creates the chezmoi.toml file needed for custom variables 
#           like 'ml4wDotfilesDir'.
# -----------------------------------------------------------------------------

set -e

CONFIG_FILE="$HOME/.config/chezmoi/chezmoi.toml"
ML4W_DOTFILES_REPO="$HOME/.ml4w-dotfiles"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[Chezmoi] Creating configuration file with required variables..."
    
    mkdir -p "$HOME/.config/chezmoi"
    
    cat <<EOF > "$CONFIG_FILE"
[data]
    ml4wDotfilesDir = "$ML4W_DOTFILES_REPO"
EOF

    echo "[Chezmoi] Config file created."
else
    echo "[Chezmoi] Config file already exists. Skipping creation."
fi