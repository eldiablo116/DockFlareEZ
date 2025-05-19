#!/bin/bash

# --- Version ---
VERSION="v1.5"

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RED='\e[31m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Sudo Check ---
if [ "$EUID" -ne 0 ]; then
  echo -e "$PREFIX ⚠️  Please run this tool using: ${ORANGE}sudo -E dfapps${RESET}"
  exit 1
fi

if [ -z "$SUDO_USER" ]; then
  echo -e "$PREFIX ❌ Cannot determine the original user. Please use: ${ORANGE}sudo -E dfapps${RESET}"
  exit 1
fi

# Try to source original user’s environment (Cloudflare vars) from their bashrc
source "/home/$SUDO_USER/.bashrc"

# Verify that Cloudflare vars are now set
if [[ -z "$CLOUDFLARE_EMAIL" || -z "$CLOUDFLARE_API_KEY" || -z "$CF_ZONE" ]]; then
  echo -e "$PREFIX ❌ Cloudflare environment variables not found."
  echo -e "$PREFIX Please make sure you've run ${ORANGE}dfconfig${RESET} as your normal user to save them first."
  echo -e "$PREFIX Then rerun this tool using: ${ORANGE}sudo -E dfapps${RESET}"
  exit 1
fi

# --- Load user environment if running with sudo ---
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
  USER_BASHRC="/home/$SUDO_USER/.bashrc"
  if [ -f "$USER_BASHRC" ]; then
    # shellcheck disable=SC1090
    source "$USER_BASHRC"
  fi
fi

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

check_var() {
  local name=$1
  local value=${!name}
  if [ -n "$value" ]; then
    echo -e "$PREFIX $name: ${GREEN}✅${RESET}"
  else
    echo -e "$PREFIX $name: ${RED}❌${RESET}"
  fi
}

check_var CLOUDFLARE_EMAIL
check_var CLOUDFLARE_API_KEY
check_var CF_ZONE

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

# --- Download & Execute App Installer ---
APP_SCRIPT_URL="$GITHUB_REPO/$APP_ID.sh"
APP_SCRIPT_TMP="/tmp/${APP_ID}.sh"

echo -e "$PREFIX ⬇️ Downloading latest $APP_NAME installer..."
curl -fsSL "$APP_SCRIPT_URL" -o "$APP_SCRIPT_TMP"

if [ $? -ne 0 ]; then
  echo -e "$PREFIX ❌ Failed to download $APP_SCRIPT_URL"
  exit 1
fi

chmod +x "$APP_SCRIPT_TMP"
"$APP_SCRIPT_TMP"
