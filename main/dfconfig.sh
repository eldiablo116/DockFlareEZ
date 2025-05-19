#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Load current values from .bashrc (if present) ---
EMAIL=$(grep 'CLOUDFLARE_EMAIL=' ~/.bashrc | cut -d= -f2- | tr -d '"')
KEY=$(grep 'CLOUDFLARE_API_KEY=' ~/.bashrc | cut -d= -f2- | tr -d '"')
ZONE=$(grep 'CF_ZONE=' ~/.bashrc | cut -d= -f2- | tr -d '"')

echo -e "$PREFIX 📦 Current Cloudflare config:"
echo -e "$PREFIX Email:  ${EMAIL:-<not set>}"
echo -e "$PREFIX API Key: ${KEY:+<set>}${KEY:-<not set>}"
echo -e "$PREFIX Domain: ${ZONE:-<not set>}"

read -p "$PREFIX Do you want to update these values? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo -e "$PREFIX 🚫 No changes made."
  exit 0
fi

# --- Prompt for new values ---
read -p "$PREFIX Enter new Cloudflare email: " EMAIL
read -p "$PREFIX Enter new Cloudflare API key: " KEY
read -p "$PREFIX Enter your domain (e.g. example.com): " ZONE

# --- Remove existing entries ---
sed -i '/CLOUDFLARE_EMAIL=/d' ~/.bashrc
sed -i '/CLOUDFLARE_API_KEY=/d' ~/.bashrc
sed -i '/CF_ZONE=/d' ~/.bashrc

# --- Add new ones ---
{
  echo ""
  echo "# DockFlareEZ Cloudflare credentials (updated)"
  echo "export CLOUDFLARE_EMAIL=\"$EMAIL\""
  echo "export CLOUDFLARE_API_KEY=\"$KEY\""
  echo "export CF_ZONE=\"$ZONE\""
} >> ~/.bashrc

echo -e "$PREFIX ✅ Configuration updated."
echo -e "$PREFIX 🔁 Please run: source ~/.bashrc or restart your session to apply."
