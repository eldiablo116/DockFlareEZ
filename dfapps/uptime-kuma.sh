#!/bin/bash

# --- Version ---
VERSION="v1.2"

# --- App Info ---
APP_NAME="Uptime Kuma"
APP_ID="uptime-kuma"
GITHUB_REPO="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main"

# --- Branding ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"

# --- Check Docker ---
if ! command -v docker &>/dev/null; then
  echo -e "$PREFIX ❌ Docker is not installed. Aborting."
  exit 1
fi

# --- Check Cloudflare vars ---
if [ -z "$CLOUDFLARE_EMAIL" ] || [ -z "$CLOUDFLARE_API_KEY" ] || [ -z "$CF_ZONE" ]; then
  echo -e "$PREFIX ❌ Cloudflare env vars not set. Use 'dfconfig' to configure."
  exit 1
fi

# --- Prepare ---
SUBDOMAIN="${APP_ID}-$(shuf -i 1000-9999 -n 1)"
APP_DIR="/opt/containers/$APP_ID"
mkdir -p "$APP_DIR"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
VPS_IP=$(curl -s https://icanhazip.com)

# --- Write Compose ---
cat <<EOF > "$COMPOSE_FILE"
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - ./data:/app/data
    labels:
      traefik.enable: true

      # HTTP
      traefik.http.routers.${APP_ID}-http.entrypoints: web
      traefik.http.routers.${APP_ID}-http.rule: "Host('${SUBDOMAIN}.${CF_ZONE}')"
      traefik.http.routers.${APP_ID}-http.middlewares: globalHeaders@file,redirect-to-https@docker,robotHeaders@file
      traefik.http.routers.${APP_ID}-http.service: ${APP_ID}

      # HTTPS
      traefik.http.routers.${APP_ID}.entrypoints: websecure
      traefik.http.routers.${APP_ID}.rule: "Host('${SUBDOMAIN}.${CF_ZONE}')"
      traefik.http.routers.${APP_ID}.middlewares: globalHeaders@file,secureHeaders@file,robotHeaders@file
      traefik.http.routers.${APP_ID}.tls.certresolver: cloudflare
      traefik.http.routers.${APP_ID}.tls.options: securetls@file
      traefik.http.routers.${APP_ID}.service: ${APP_ID}

      # Internal port
      traefik.http.services.${APP_ID}.loadbalancer.server.port: 3001

    networks:
      - dockflare

networks:
  dockflare:
    external: true
EOF

# --- Deploy ---
cd "$APP_DIR"
echo -e "$PREFIX 🚀 Deploying $APP_NAME..."
docker compose up -d

# --- Wait for container to come up ---
echo -e "$PREFIX ⏳ Waiting for '${APP_ID}' container to start..."
sleep 5

if ! docker ps --format '{{.Names}}' | grep -q "$APP_ID"; then
  echo -e "$PREFIX ❌ Container '${APP_ID}' failed to start. Please check logs."
  exit 1
fi

# --- Validate VPS IP ---
VPS_IP=$(curl -4 -s https://icanhazip.com | tr -d '\n')
if [[ ! "$VPS_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "$PREFIX ❌ VPS IP is invalid. Skipping DNS registration."
else
  export CLOUDFLARE_EMAIL
  export CLOUDFLARE_API_KEY
  /opt/dns-helper.sh "$SUBDOMAIN" "$CF_ZONE" "$VPS_IP"
fi

# --- Result ---
echo -e "$PREFIX ✅ $APP_NAME deployed at https://$SUBDOMAIN.$CF_ZONE"
