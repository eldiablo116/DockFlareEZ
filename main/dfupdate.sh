#!/bin/bash

# --- Version ---
VERSION="v1.1"

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- URLs ---
declare -A COMPONENTS
COMPONENTS["dfapps"]="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ/main/main/dfapps.sh"
COMPONENTS["dfdeploy"]="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ/main/main/dfdeploy.sh"
COMPONENTS["dfconfig"]="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ/main/main/dfconfig.sh"
COMPONENTS["dfupdate"]="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ/main/main/dfupdate.sh"

echo -e "$PREFIX 🔄 Updating DockFlareEZ tools..."

for tool in "${!COMPONENTS[@]}"; do
  URL="${COMPONENTS[$tool]}"
  echo -e "\n$PREFIX 📦 Checking $tool..."

  # Get local version
  if [[ -f "/usr/local/bin/$tool" ]]; then
    LOCAL_VERSION=$(grep -E '^# --- Version ---' "/usr/local/bin/$tool" -A 1 | tail -n 1 | cut -d'"' -f2)
  else
    LOCAL_VERSION="(not installed)"
  fi

  # Get latest version
  LATEST_VERSION=$(curl -fsSL "$URL" | grep -E '^# --- Version ---' -A 1 | tail -n 1 | cut -d'"' -f2)

  echo -e "$PREFIX 🧮 Local version:  $LOCAL_VERSION"
  echo -e "$PREFIX 🆕 Latest version: $LATEST_VERSION"

  if [[ "$LOCAL_VERSION" != "$LATEST_VERSION" || "$LOCAL_VERSION" == "(not installed)" || -z "$LATEST_VERSION" ]]; then
    read -p "$(echo -e "$PREFIX 🚀 Update $tool to $LATEST_VERSION? (y/n): ")" CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      sudo curl -fsSL "$URL" -o "/usr/local/bin/$tool"
      sudo chmod +x "/usr/local/bin/$tool"
      echo -e "$PREFIX ✅ $tool updated to $LATEST_VERSION."
    else
      echo -e "$PREFIX ⚠️ Skipped updating $tool."
    fi
  else
    echo -e "$PREFIX ✅ $tool is already up to date."
  fi
done

echo -e "\n$PREFIX ✅ All components checked."
