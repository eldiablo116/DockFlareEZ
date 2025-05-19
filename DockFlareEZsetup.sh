#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'

# --- Branding ---
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"
echo -e "${ORANGE}===============================\n   DockFlare EZSetup v3.2\n===============================${RESET}\n"

# --- Track Success Flags ---
UPDATE_OK=false
CF_OK=false
DNS_OK=false
USER_OK=false
DOCKER_OK=false
TRAEFIK_OK=false
PORTAINER_OK=false

# --- Update Check First ---
echo -e "$PREFIX 🔍 Checking for system updates..."
apt update -qq > /dev/null
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

if [ "$UPGRADABLE" -gt 0 ]; then
  echo -e "$PREFIX 🔄 Updates available."
  read -p "$(echo -e "$PREFIX Install updates now? (y/n): ")" DOUPGRADE
  if [[ "$DOUPGRADE" =~ ^[Yy]$ ]]; then
    echo -e "$PREFIX ⬇️ Installing updates..."
    UPGRADE_OUTPUT=$(apt upgrade -y -qq)
    if echo "$UPGRADE_OUTPUT" | grep -q "0 upgraded"; then
      echo -e "$PREFIX ✅ No updates applied (phased)."
    else
      read -p "$(echo -e "$PREFIX Reboot now to finish updates? (y/n): ")" REBOOTAFTERUPGRADE
      if [[ "$REBOOTAFTERUPGRADE" =~ ^[Yy]$ ]]; then
        echo -e "$PREFIX 🔁 Rebooting. Please re-run this script."
        reboot
        exit 0
      else
        echo -e "$PREFIX ⚠️ Please reboot manually before re-running this script."
        exit 0
      fi
    fi
  else
    echo -e "$PREFIX ✅ System is up to date."
  fi
else
  echo -e "$PREFIX ✅ System is up to date."
fi

UPDATE_OK=true

# --- Cloudflare Input ---
read -p "$(echo -e "$PREFIX Cloudflare email: ")" CFEMAIL
read -p "$(echo -e "$PREFIX Cloudflare API token: ")" CFTOKEN
read -p "$(echo -e "$PREFIX Your domain (e.g., example.com): ")" DOMAIN

# --- Cloudflare Validation ---
CF_ZONE=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ "$CF_ZONE_ID" == "null" || -z "$CF_ZONE_ID" ]]; then
  echo -e "$PREFIX ❌ Invalid Cloudflare credentials or domain."
  exit 1
else
  echo -e "$PREFIX ✅ Cloudflare API verified. Zone ID: $CF_ZONE_ID"
  CF_OK=true
fi

# --- DNS Propagation Test ---
TEST_SUB="dockflareez-test-$(shuf -i 1000-9999 -n 1)"
VPS_IP=$(curl -s ifconfig.me)

curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"$TEST_SUB.$CF_ZONE\",\"content\":\"$VPS_IP\",\"ttl\":120,\"proxied\":false}" > /dev/null

echo -e "$PREFIX 🕵️ Created test DNS record: $TEST_SUB.$CF_ZONE"
echo -e "$PREFIX ⏳ Waiting for DNS to resolve..."

for i in {1..30}; do
  if ping -c 1 "$TEST_SUB.$CF_ZONE" &>/dev/null; then
    echo -e "$PREFIX ✅ DNS resolved successfully."
    DNS_OK=true
    break
  fi
  sleep 2
done

if [ "$DNS_OK" != true ]; then
  echo -e "$PREFIX ❌ DNS failed to resolve after 60 seconds."
  exit 1
fi

# Clean up test record
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$TEST_SUB.$CF_ZONE" \
  -H "Authorization: Bearer $CFTOKEN" | jq -r '.result[0].id')

if [[ -n "$RECORD_ID" && "$RECORD_ID" != "null" ]]; then
  curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CFTOKEN" > /dev/null
  echo -e "$PREFIX 🧹 Cleaned up test DNS record."
fi

# --- Username Prompt ---
read -p "$(echo -e "$PREFIX Enter new admin username: ")" NEWUSER

# --- SSH Setup ---
SSHPORT=$(shuf -i 2000-65000 -n 1)
USERPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

adduser --disabled-password --gecos "" "$NEWUSER" > /dev/null
usermod -aG sudo "$NEWUSER"
echo "$NEWUSER:$USERPASS" | chpasswd
touch "/home/$NEWUSER/.Xauthority"
chown $NEWUSER:$NEWUSER "/home/$NEWUSER/.Xauthority"
sed -i "s/#Port 22/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/Port .*/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart ssh || systemctl restart ssh.service
USER_OK=true
echo -e "$PREFIX 👤 User '$NEWUSER' created with password login."
echo -e "$PREFIX 🔐 SSH set to port $SSHPORT"

# --- Docker Install ---
echo -e "$PREFIX 🐳 Installing Docker..."
apt install -y -qq ca-certificates curl gnupg lsb-release > /dev/null
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor \
  -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt update -qq
apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
systemctl enable docker > /dev/null
usermod -aG docker "$NEWUSER"
DOCKER_OK=true
echo -e "$PREFIX ✅ Docker installed."

# --- Deploy Traefik ---
mkdir -p /opt/traefik && touch /opt/traefik/acme.json
chmod 600 /opt/traefik/acme.json

cat <<EOF > /opt/traefik/docker-compose.yml
version: "3"
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
    restart: unless-stopped
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--providers.docker=true"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.cloudflare.acme.email=$CFEMAIL"
      - "--certificatesresolvers.cloudflare.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    environment:
      - CF_API_TOKEN=$CFTOKEN
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./acme.json:/letsencrypt/acme.json
    networks:
      - dockflare
networks:
  dockflare:
    external: true
EOF

docker network create dockflare > /dev/null 2>&1 || true
cd /opt/traefik && docker compose up -d && TRAEFIK_OK=true
echo -e "$PREFIX 🚦 Traefik deployed."

# --- Deploy Portainer ---
mkdir -p /opt/portainer

cat <<EOF > /opt/portainer/docker-compose.yml
version: "3"
services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(\`portainer.$CF_ZONE\`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=cloudflare"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - dockflare
volumes:
  portainer_data:
networks:
  dockflare:
    external: true
EOF

cd /opt/portainer && docker compose up -d && PORTAINER_OK=true
echo -e "$PREFIX 🧭 Portainer deployed at https://portainer.$CF_ZONE"

# --- Summary Report ---
echo -e "\n${ORANGE}========== SETUP SUMMARY ==========${RESET}"
echo -e "$PREFIX System update:        $([ "$UPDATE_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Cloudflare verified:  $([ "$CF_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX DNS test passed:      $([ "$DNS_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX User created:         $([ "$USER_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Docker installed:     $([ "$DOCKER_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Traefik running:      $([ "$TRAEFIK_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Portainer running:    $([ "$PORTAINER_OK" = true ] && echo ✅ || echo ❌)"

echo -e "\n${GREEN}Done! Your VPS is ready. SSH login: ssh -p $SSHPORT $NEWUSER@<your-server-ip>${RESET}"
echo -e "${GREEN}Temporary password: $USERPASS${RESET}"
