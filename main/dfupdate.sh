#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

echo -e "$PREFIX 🔄 Updating DockFlareEZ tools..."

# --- Update dfapps ---
echo -e "$PREFIX 📦 Updating dfapps..."
curl -fsSL https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/main/dfaspps.sh -o /usr/local/bin/dfapps
chmod +x /usr/local/bin/dfapps

# --- Update dfconfig ---
echo -e "$PREFIX 📦 Updating dfconfig..."
curl -fsSL https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/main/dfconfig.sh -o /usr/local/bin/dfconfig
chmod +x /usr/local/bin/dfconfig

# --- Success ---
echo -e "$PREFIX ✅ All components updated successfully."
