#!/bin/bash

# --- Branding ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Root check ---
if [[ "$EUID" -ne 0 ]]; then
  echo -e "$PREFIX 🔐 Root privileges required. Re-running with sudo..."
  exec sudo "$0" "$@"
fi

echo -e "$PREFIX 🔄 Updating DockFlareEZ tools..."

TOOLS=("dfapps" "dfconfig" "dfdeploy" "dfupdate" "dfuninstall")

for TOOL in "${TOOLS[@]}"; do
  echo -e "$PREFIX 📦 Updating $TOOL..."
  curl -fsSL "https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/main/${TOOL}.sh" -o "/usr/local/bin/$TOOL"
  chmod +x "/usr/local/bin/$TOOL"
done

echo -e "$PREFIX ✅ All components updated successfully."
