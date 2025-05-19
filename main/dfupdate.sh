#!/bin/bash

# --- Version ---
VERSION="v1.1"

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Tools to check ---
TOOLS=("dfapps" "dfconfig" "dfdeploy" "dfupdate")
GITHUB_BASE="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/main"

echo -e "$PREFIX 🔄 Updating DockFlareEZ tools..."

for TOOL in "${TOOLS[@]}"; do
  LOCAL_PATH="/usr/local/bin/$TOOL"
  REMOTE_URL="$GITHUB_BASE/${TOOL}.sh"

  echo -e "\n$PREFIX 📦 Checking $TOOL..."

  REMOTE_VERSION=$(curl -fsSL "$REMOTE_URL" | grep -E '^VERSION=' | cut -d'"' -f2)

  if [ ! -f "$LOCAL_PATH" ]; then
    echo -e "$PREFIX ➕ $TOOL not found locally. Installing version $REMOTE_VERSION..."
    curl -fsSL "$REMOTE_URL" -o "$LOCAL_PATH"
    chmod +x "$LOCAL_PATH"
    echo -e "$PREFIX ✅ $TOOL installed."
    continue
  fi

  LOCAL_VERSION=$(grep -E '^VERSION=' "$LOCAL_PATH" | cut -d'"' -f2)

  if [ -z "$LOCAL_VERSION" ]; then
    echo -e "$PREFIX ⚠️ Local version missing. Updating to latest ($REMOTE_VERSION)..."
    curl -fsSL "$REMOTE_URL" -o "$LOCAL_PATH"
    chmod +x "$LOCAL_PATH"
    echo -e "$PREFIX ✅ $TOOL updated."
    continue
  fi

  echo -e "$PREFIX 🧮 Local version:  $LOCAL_VERSION"
  echo -e "$PREFIX 🆕 Latest version: $REMOTE_VERSION"

  if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
    read -p "$(echo -e "$PREFIX 🚀 Update $TOOL to $REMOTE_VERSION? (y/n): ")" CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      curl -fsSL "$REMOTE_URL" -o "$LOCAL_PATH"
      chmod +x "$LOCAL_PATH"
      echo -e "$PREFIX ✅ $TOOL updated to $REMOTE_VERSION"
    else
      echo -e "$PREFIX ❌ Skipped updating $TOOL"
    fi
  else
    echo -e "$PREFIX ✅ $TOOL is already up to date"
  fi
done

echo -e "\n$PREFIX 🧼 Update check complete."
