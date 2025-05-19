#!/bin/bash

# --- Version ---
VERSION="v1.1"

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Handle --update flag ---
if [[ "$1" == "--update" ]]; then
  echo -e "$PREFIX 🔄 Updating dfapps..."
  curl -fsSL https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/main/dfaspps.sh -o /usr/local/bin/dfapps
  chmod +x /usr/local/bin/dfapps
  echo -e "$PREFIX ✅ dfapps has been updated."
  exit 0
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

echo -e "$PREFIX CLOUDFLARE_EMAIL: ${CLOUDFLARE_EMAIL:-<not set>}"
echo -e "$PREFIX CLOUDFLARE_API_KEY: ${CLOUDFLARE_API_KEY:+<set>}${CLOUDFLARE_API_KEY:-<not set>}"
echo -e "$PREFIX CF_ZONE (domain): ${CF_ZONE:-<not set>}"

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

SUBDOMAIN="${APP_ID}-$(shuf -i 1000-9999 -n 1)"
APP_DIR="/opt/containers/$APP_ID"
mkdir -p "$APP_DIR"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

# --- Fetch Template ---
TEMPLATE_URL="$GITHUB_REPO/$APP_ID.yml"
echo -e "$PREFIX ⬇️ Downloading template from GitHub..."
curl -fsSL "$TEMPLATE_URL" -o "$COMPOSE_FILE"

if [ $? -ne 0 ]; then
  echo -e "$PREFIX ❌ Failed to download template for $APP_NAME"
  exit 1
fi

# --- Replace Subdomain Placeholder ---
sed -i "s/{{SUBDOMAIN}}/$SUBDOMAIN/g" "$COMPOSE_FILE"
sed -i "s/{{DOMAIN}}/$CF_ZONE/g" "$COMPOSE_FILE"

# --- Optional Prompts ---
if grep -q '{{ADMIN_USER}}' "$COMPOSE_FILE"; then
  read -p "$PREFIX Enter admin username: " ADMIN_USER
  sed -i "s/{{ADMIN_USER}}/$ADMIN_USER/g" "$COMPOSE_FILE"
fi
if grep -q '{{ADMIN_PASS}}' "$COMPOSE_FILE"; then
  read -p "$PREFIX Enter admin password: " ADMIN_PASS
  sed -i "s/{{ADMIN_PASS}}/$ADMIN_PASS/g" "$COMPOSE_FILE"
fi

cd "$APP_DIR"
docker compose up -d

# --- Run DNS Helper ---
export CLOUDFLARE_EMAIL
export CLOUDFLARE_API_KEY
/opt/dns-helper.sh "$SUBDOMAIN" "$CF_ZONE" "$VPS_IP"

echo -e "$PREFIX ✅ $APP_NAME deployed at https://$SUBDOMAIN.$CF_ZONE"
