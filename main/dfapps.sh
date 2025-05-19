#!/bin/bash

# --- Version ---
VERSION="v1.1"

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- App Catalog ---
declare -A APPS
APPS["Uptime Kuma"]="Self-hosted monitoring & alerts"

GITHUB_REPO="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/dfapps"

# --- Check Requirements ---
if ! command -v docker &>/dev/null; then
  echo -e "$PREFIX ❌ Docker not found. This script requires Docker."
  exit 1
fi

# --- Prompt for CF credentials (check existing first) ---
echo -e "$PREFIX 🌐 Checking Cloudflare environment variables..."

echo -e "$PREFIX CLOUDFLARE_EMAIL: ${CLOUDFLARE_EMAIL:-❌ Not set}"
echo -e "$PREFIX CLOUDFLARE_API_KEY: ${CLOUDFLARE_API_KEY:+✅ Set}${CLOUDFLARE_API_KEY:-❌ Not set}"
echo -e "$PREFIX CF_ZONE (domain): ${CF_ZONE:-❌ Not set}"

read -p "$PREFIX Are these correct? (y/n): " CONFIRM_ENV

if [[ ! "$CONFIRM_ENV" =~ ^[Yy]$ ]]; then
  read -p "$PREFIX Enter Cloudflare email: " CLOUDFLARE_EMAIL
  read -p "$PREFIX Enter Cloudflare API Key: " CLOUDFLARE_API_KEY
  read -p "$PREFIX Enter your domain (e.g. example.com): " CF_ZONE
fi

VPS_IP=$(curl -s https://icanhazip.com)

# --- Menu ---
echo -e "\n${ORANGE}========== DockFlareEZ App Installer ==========${RESET}"
PS3="$(echo -e "$PREFIX Select an app to install: ")"

select opt in "${!APPS[@]}" "Exit"; do
  if [[ "$opt" == "Exit" ]]; then
    echo -e "$PREFIX 👋 Exiting installer."
    exit 0
  elif [[ -n "${APPS[$opt]}" ]]; then
    APP_NAME="$opt"
    APP_ID="$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    echo -e "$PREFIX 📦 ${APPS[$opt]}"
    break
  else
    echo -e "$PREFIX ❌ Invalid option"
  fi
done

# --- Run Installer Script ---
SCRIPT_URL="$GITHUB_REPO/$APP_ID.sh"
echo -e "$PREFIX ⬇️ Downloading and executing $APP_NAME installer..."
curl -fsSL "$SCRIPT_URL" -o "/tmp/$APP_ID.sh"

if [ $? -ne 0 ]; then
  echo -e "$PREFIX ❌ Failed to download installer script for $APP_NAME"
  exit 1
fi

chmod +x "/tmp/$APP_ID.sh"
CLOUDFLARE_EMAIL="$CLOUDFLARE_EMAIL" CLOUDFLARE_API_KEY="$CLOUDFLARE_API_KEY" CF_ZONE="$CF_ZONE" VPS_IP="$VPS_IP" "/tmp/$APP_ID.sh"
