#!/bin/bash
set -euo pipefail

# Path to the script that creates ~/.config/chezmoi/chezmoi.toml
CONFIG_SCRIPT="./create-chezmoi-config.sh"

echo "[Bootstrap] Running config creation script…"
bash "$CONFIG_SCRIPT"

echo "[Bootstrap] Running chezmoi apply…"
chezmoi apply

echo "[Bootstrap] Done."
