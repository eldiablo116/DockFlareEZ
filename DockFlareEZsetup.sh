#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'

# --- Branding ---
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"
echo -e "${ORANGE}===============================\n   DockFlare EZSetup v3.0\n===============================${RESET}\n"

# --- User Input ---
read -p "$(echo -e "$PREFIX Enter new admin username: ")" NEWUSER
read -p "$(echo -e "$PREFIX Cloudflare email: ")" CFEMAIL
read -p "$(echo -e "$PREFIX Cloudflare API token: ")" CFTOKEN
read -p "$(echo -e "$PREFIX Your domain (e.g., example.com): ")" DOMAIN

# --- Random SSH Port ---
SSHPORT=$(shuf -i 2000-65000 -n 1)
echo -e "$PREFIX 📦 SSH port: $SSHPORT"

# --- Update Check ---
echo -e "$PREFIX 🔍 Checking for updates..."
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
        echo -e "$PREFIX 🔁 Rebooting. Re-run script after restart."
        reboot
        exit 0
      else
        echo -e "$PREFIX ⚠️ Reboot manually later."
        exit 0
      fi
    fi
  fi
else
  echo -e "$PREFIX ✅ System is up to date."
fi

# --- Cloudflare Check ---
CF_ZONE=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ "$CF_ZONE_ID" == "null" || -z "$CF_ZONE_ID" ]]; then
  echo -e "$PREFIX ❌ Failed to verify Cloudflare API credentials or domain ($CF_ZONE)."
  exit 1
fi

echo -e "$PREFIX ✅ Cloudflare API verified. Zone ID: $CF_ZONE_ID"

# --- DNS Test ---
TEST_SUBDOMAIN="dockflareez-test-$(shuf -i 1000-9999 -n 1)"
VPS_IP=$(curl -s ifconfig.me)

curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"$TEST_SUBDOMAIN.$CF_ZONE\",\"content\":\"$VPS_IP\",\"ttl\":120,\"proxied\":false}" > /dev/null

echo -e "$PREFIX 🕵️ Created test record: $TEST_SUBDOMAIN.$CF_ZONE"
echo -e "$PREFIX ⏳ Waiting for DNS to resolve..."

for i in {1..30}; do
  if ping -c 1 "$TEST_SUBDOMAIN.$CF_ZONE" &>/dev/null; then
    echo -e "$PREFIX ✅ DNS resolved!"
    break
  fi
  sleep 2
done

if ! ping -c 1 "$TEST_SUBDOMAIN.$CF_ZONE" &>/dev/null; then
  echo -e "$PREFIX ❌ DNS propagation failed."
  exit 1
fi

RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$TEST_SUBDOMAIN.$CF_ZONE" \
  -H "Authorization: Bearer $CFTOKEN" | jq -r '.result[0].id')

if [[ -n "$RECORD_ID" && "$RECORD_ID" != "null" ]]; then
  curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CFTOKEN" > /dev/null
  echo -e "$PREFIX 🧹 Cleaned up test record."
fi

# --- Add Portainer A Record ---
PORTAINER_SUB="portainer.$CF_ZONE"
RECORD_EXISTS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$PORTAINER_SUB" \
  -H "Authorization: Bearer $CFTOKEN")
EXISTING_ID=$(echo "$RECORD_EXISTS" | jq -r '.result[0].id')
EXISTING_IP=$(echo "$RECORD_EXISTS" | jq -r '.result[0].content')

if [[ "$EXISTING_ID" == "null" || -z "$EXISTING_ID" ]]; then
  echo -e "$PREFIX Creating A record for Portainer..."
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CFTOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$PORTAINER_SUB\",\"content\":\"$VPS_IP\",\"ttl\":120,\"proxied\":false}" > /dev/null
else
  if [[ "$EXISTING_IP" != "$VPS_IP" ]]; then
    echo -e "$PREFIX Updating A record for Portainer..."
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$EXISTING_ID" \
      -H "Authorization: Bearer $CFTOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$PORTAINER_SUB\",\"content\":\"$VPS_IP\",\"ttl\":120,\"proxied\":false}" > /dev/null
  else
    echo -e "$PREFIX Portainer A record already up-to-date."
  fi
fi

# --- User & SSH ---
adduser --disabled-password --gecos "" "$NEWUSER" > /dev/null
usermod -aG sudo "$NEWUSER"
touch /home/$NEWUSER/.Xauthority
chown $NEWUSER:$NEWUSER /home/$NEWUSER/.Xauthority
PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
echo "$NEWUSER:$PASS" | chpasswd
sed -i "s/#Port 22/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/Port .*/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart ssh || systemctl restart ssh.service
echo -e "$PREFIX User created: $NEWUSER"
echo -e "$PREFIX SSH login: ssh -p $SSHPORT $NEWUSER@your-server-ip"
echo -e "$PREFIX Temporary password: $PASS"

# --- Install Docker ---
echo -e "$PREFIX Installing Docker..."
apt install -y -qq ca-certificates curl gnupg lsb-release > /dev/null
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor \
  -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt update -qq
apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
systemctl enable docker
usermod -aG docker $NEWUSER
echo -e "$PREFIX Docker installed.. OK!"

# --- Traefik & Portainer Setup ---
mkdir -p /opt/traefik /opt/portainer
touch /opt/traefik/acme.json
chmod 600 /opt/traefik/acme.json

# Traefik Docker Compose
cat <<EOF > /opt/traefik/docker-compose.yml
version: "3"
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
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
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./acme.json:/letsencrypt/acme.json
    environment:
      - CF_API_TOKEN=$CFTOKEN
    networks:
      - dockflare
networks:
  dockflare:
    external: true
EOF

docker network create dockflare || true
cd /opt/traefik && docker compose up -d
echo -e "$PREFIX Traefik deployed.. OK!"

# Portainer Docker Compose
cat <<EOF > /opt/portainer/docker-compose.yml
version: "3"
services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(\`$PORTAINER_SUB\`)"
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

cd /opt/portainer && docker compose up -d
echo -e "$PREFIX Portainer deployed at https://$PORTAINER_SUB .. OK!"
