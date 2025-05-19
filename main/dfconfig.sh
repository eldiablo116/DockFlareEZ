#!/bin/bash

# --- Version ---
VERSION="v1.1"
#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RED='\e[31m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Config File ---
CONFIG_FILE="/home/$(whoami)/.bashrc"

# --- Extract current config ---
CF_EMAIL=$(grep 'CLOUDFLARE_EMAIL' "$CONFIG_FILE" | cut -d'"' -f2)
CF_API_KEY=$(grep 'CLOUDFLARE_API_KEY' "$CONFIG_FILE" | cut -d'"' -f2)
CF_ZONE=$(grep 'CF_ZONE' "$CONFIG_FILE" | cut -d'"' -f2)

# --- Status Indicators ---
EMAIL_STATUS=$([[ -n "$CF_EMAIL" ]] && echo "✅" || echo "❌")
API_STATUS=$([[ -n "$CF_API_KEY" ]] && echo "✅" || echo "❌")
ZONE_STATUS=$([[ -n "$CF_ZONE" ]] && echo "✅" || echo "❌")

# --- Masked API Key ---
if [[ -n "$CF_API_KEY" ]]; then
  API_MASKED="************${CF_API_KEY: -4}"
else
  API_MASKED="(not set)"
fi

# --- Show current config ---
echo -e "$PREFIX 📦 Current Cloudflare config:"
echo -e "$PREFIX Email:   $CF_EMAIL $EMAIL_STATUS"
echo -e "$PREFIX API Key: $API_MASKED $API_STATUS"
echo -e "$PREFIX Domain:  $CF_ZONE $ZONE_STATUS"

# --- Prompt to update ---
read -p "$(echo -e "$PREFIX Do you want to update these values? (y/n): ")" UPDATE
if [[ "$UPDATE" =~ ^[Yy]$ ]]; then
  read -p "$PREFIX New Cloudflare email: " NEW_EMAIL
  read -p "$PREFIX New Cloudflare API Key: " NEW_KEY
  read -p "$PREFIX New domain (zone): " NEW_ZONE

  sed -i '/CLOUDFLARE_EMAIL/d' "$CONFIG_FILE"
  sed -i '/CLOUDFLARE_API_KEY/d' "$CONFIG_FILE"
  sed -i '/CF_ZONE/d' "$CONFIG_FILE"

  echo "export CLOUDFLARE_EMAIL=\"$NEW_EMAIL\"" >> "$CONFIG_FILE"
  echo "export CLOUDFLARE_API_KEY=\"$NEW_KEY\"" >> "$CONFIG_FILE"
  echo "export CF_ZONE=\"$NEW_ZONE\"" >> "$CONFIG_FILE"

  echo -e "$PREFIX ✅ Cloudflare credentials updated in $CONFIG_FILE"
  echo -e "$PREFIX 🔄 Please run: source $CONFIG_FILE"
else
  echo -e "$PREFIX ❌ No changes made."
fi
