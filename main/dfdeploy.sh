#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]"

# --- Run docker compose up -d ---
docker compose up -d "$@"

# --- DNS Handling ---
if [ -f docker-compose.yml ]; then
  HOST_LINE=$(grep -oE 'Host\("([a-zA-Z0-9.-]+)"\)' docker-compose.yml | head -n 1)
  if [ -n "$HOST_LINE" ]; then
    FQDN=$(echo "$HOST_LINE" | cut -d'"' -f2)
    SUBDOMAIN="${FQDN%%.*}"
    DOMAIN="${FQDN#*.}"
    IP=$(curl -s https://icanhazip.com)

    echo -e "$PREFIX 🛰️  Detected domain: $FQDN"
    echo -e "$PREFIX 🔧 Running DNS update for $SUBDOMAIN.$DOMAIN → $IP"

    export CLOUDFLARE_EMAIL="$CLOUDFLARE_EMAIL"
    export CLOUDFLARE_API_KEY="$CLOUDFLARE_API_KEY"
    /opt/dns-helper.sh "$SUBDOMAIN" "$DOMAIN" "$IP"
  else
    echo -e "$PREFIX ⚠️  No Host(\"...\") rule found in docker-compose.yml"
  fi
else
  echo -e "$PREFIX ❌ No docker-compose.yml in this directory."
fi
