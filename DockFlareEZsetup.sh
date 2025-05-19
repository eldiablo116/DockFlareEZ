#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'

# --- Branding ---
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"
echo -e "${ORANGE}===============================\n   DockFlare EZSetup v5.4c\n===============================${RESET}\n"

# --- Reusable Function: Prompt for DNS Record ---
create_dns_record_prompt() {
  local SUBDOMAIN=$1
  local DOMAIN=$2
  local IP=$3

  read -p "$(echo -e "$PREFIX 🌐 Create Cloudflare DNS record for '${SUBDOMAIN}.${DOMAIN}'? (y/n): ")" CREATE_DNS
  if [[ "$CREATE_DNS" =~ ^[Yy]$ ]]; then
    export CLOUDFLARE_EMAIL="$CFEMAIL"
    export CLOUDFLARE_API_KEY="$CFAPIKEY"
    /opt/dns-helper.sh "$SUBDOMAIN" "$DOMAIN" "$IP"
  else
    echo -e "$PREFIX ⚠️ Skipped DNS record creation for $SUBDOMAIN."
  fi
}

# --- Preflight Check: Existing Containers (only if Docker exists) ---
EXISTING_CONTAINERS=()

if command -v docker >/dev/null 2>&1; then
  if docker ps -a --format '{{.Names}}' | grep -q "^traefik$"; then
    EXISTING_CONTAINERS+=("traefik")
  fi

  if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
    EXISTING_CONTAINERS+=("portainer")
  fi
fi

if [ ${#EXISTING_CONTAINERS[@]} -gt 0 ]; then
  echo -e "$PREFIX ⚠️  We detected existing container(s): ${EXISTING_CONTAINERS[*]}"
  echo -e "$PREFIX ℹ️  We recommend running this script on a fresh VPS to avoid conflicts."

  read -p "$(echo -e "$PREFIX Would you like to uninstall existing DockFlareEZ components and reset the VPS? (y/n): ")" DO_UNINSTALL
  if [[ "$DO_UNINSTALL" =~ ^[Yy]$ ]]; then
    echo -e "$PREFIX 🧹 Removing existing containers and config..."
    docker stop traefik portainer > /dev/null 2>&1
    docker rm traefik portainer > /dev/null 2>&1
    docker volume rm portainer_portainer_data > /dev/null 2>&1
    docker network rm dockflare > /dev/null 2>&1
    cd /
    rm -rf /opt/traefik /opt/portainer > /dev/null 2>&1

    echo -e "$PREFIX 🔧 Uninstalling Docker..."
    apt purge -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    apt autoremove -y -qq > /dev/null 2>&1
    rm -rf /var/lib/docker /etc/docker /var/lib/containerd /var/run/docker.sock > /dev/null 2>&1
    echo -e "$PREFIX ✅ Docker and related components uninstalled."

    echo -e "$PREFIX 🔐 Resetting SSH port to 22..."
    sed -i 's/^Port .*/Port 22/' /etc/ssh/sshd_config
    systemctl restart ssh || systemctl restart ssh.service
    echo -e "$PREFIX 🔐 SSH port reset to 22 for next login."

    echo -e "$PREFIX 🔁 Reboot is required to complete cleanup."
    echo -e "$PREFIX 💡 After reboot, please re-run this script from a fresh terminal session."

    read -p "$(echo -e "$PREFIX Reboot now? (y/n): ")" CONFIRM_REBOOT
    if [[ "$CONFIRM_REBOOT" =~ ^[Yy]$ ]]; then
      reboot
    else
      echo -e "$PREFIX ⚠️ Reboot skipped. Please reboot manually before continuing."
    fi

    exit 0
  else
    echo -e "$PREFIX ❌ Aborting installation. Please clean up manually or rerun this script on a fresh VPS."
    exit 1
  fi
fi

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
DEBIAN_FRONTEND=noninteractive apt update -qq > /dev/null 2>&1
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

if [ "$UPGRADABLE" -gt 0 ]; then
  echo -e "$PREFIX 🔄 Updates available."
  read -p "$(echo -e "$PREFIX Install updates now? (y/n): ")" DOUPGRADE
  if [[ "$DOUPGRADE" =~ ^[Yy]$ ]]; then
    echo -e "$PREFIX ⬇️ Installing updates..."
    UPGRADE_OUTPUT=$(DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq 2>/dev/null)
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
    echo -e "$PREFIX ✅ Skipped installing updates."
  fi
else
  echo -e "$PREFIX ✅ System is up to date."
fi

UPDATE_OK=true

# --- Cloudflare Input ---
read -p "$(echo -e "$PREFIX Cloudflare email: ")" CFEMAIL
read -p "$(echo -e "$PREFIX Cloudflare Global API Key: ")" CFAPIKEY
read -p "$(echo -e "$PREFIX Your domain (e.g., example.com): ")" DOMAIN

# --- Zone detection ---
CF_ZONE="$DOMAIN"
CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE" \
  -H "X-Auth-Email: $CFEMAIL" \
  -H "X-Auth-Key: $CFAPIKEY" \
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
VPS_IP=$(curl -4 -s https://icanhazip.com | tr -d '\n')

RECORD_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "X-Auth-Email: $CFEMAIL" \
  -H "X-Auth-Key: $CFAPIKEY" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"$TEST_SUB.$CF_ZONE\",\"content\":\"$VPS_IP\",\"ttl\":120,\"proxied\":false}")

if ! echo "$RECORD_RESPONSE" | jq -e '.success' | grep true >/dev/null; then
  echo -e "$PREFIX ❌ Failed to create DNS record:"
  echo "$RECORD_RESPONSE" | jq .
  exit 1
fi

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

# --- Clean up test record ---
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$TEST_SUB.$CF_ZONE" \
  -H "X-Auth-Email: $CFEMAIL" \
  -H "X-Auth-Key: $CFAPIKEY" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -n "$RECORD_ID" && "$RECORD_ID" != "null" ]]; then
  curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "X-Auth-Email: $CFEMAIL" \
    -H "X-Auth-Key: $CFAPIKEY" \
    -H "Content-Type: application/json" > /dev/null
  echo -e "$PREFIX 🧹 Cleaned up test DNS record."
fi

# --- Username Prompt ---
while true; do
  read -p "$(echo -e "$PREFIX Enter new admin username: ")" NEWUSER

  # Validate username (alphanumeric + optional underscore or hyphen, no dots)
  if [[ "$NEWUSER" =~ ^[a-z_][a-z0-9_-]{2,31}$ ]]; then
    break
  else
    echo -e "$PREFIX ❌ Invalid username. Use only lowercase letters, numbers, underscores or hyphens. No dots or special chars."
  fi
done

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

DEBIAN_FRONTEND=noninteractive apt install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1
mkdir -p /etc/apt/keyrings

# Only write GPG key if it doesn't already exist
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor \
    -o /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

DEBIAN_FRONTEND=noninteractive apt update -qq > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1

systemctl enable docker > /dev/null 2>&1
usermod -aG docker "$NEWUSER"

DOCKER_OK=true
echo -e "$PREFIX ✅ Docker installed."

# --- Create DNS Helper Script ---
echo -e "$PREFIX 🛠️ Creating DNS helper script..."

cat <<'EOF' > /opt/dns-helper.sh
#!/bin/bash

# --- Usage ---
# ./dns-helper.sh <subdomain> <domain> <ip>
# Requires CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY to be exported

if [ "$#" -ne 3 ]; then
  echo "[dns-helper] ❌ Usage: \$0 <subdomain> <domain> <ip>"
  exit 1
fi

SUBDOMAIN=\$1
DOMAIN=\$2
IP=\$3
FQDN="\${SUBDOMAIN}.\${DOMAIN}"
PROXIED=true

# --- Check required env vars ---
if [ -z "\$CLOUDFLARE_EMAIL" ] || [ -z "\$CLOUDFLARE_API_KEY" ]; then
  echo "[dns-helper] ❌ CLOUDFLARE_EMAIL or CLOUDFLARE_API_KEY is not set."
  exit 1
fi

# --- Get Zone ID ---
ZONE_ID=\$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=\${DOMAIN}" \\
  -H "X-Auth-Email: \$CLOUDFLARE_EMAIL" \\
  -H "X-Auth-Key: \$CLOUDFLARE_API_KEY" \\
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [ -z "\$ZONE_ID" ] || [ "\$ZONE_ID" == "null" ]; then
  echo "[dns-helper] ❌ Failed to retrieve Zone ID for \${DOMAIN}"
  exit 1
fi

# --- Check if DNS record already exists ---
EXISTING_RECORD_ID=\$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/\${ZONE_ID}/dns_records?name=\${FQDN}" \\
  -H "X-Auth-Email: \$CLOUDFLARE_EMAIL" \\
  -H "X-Auth-Key: \$CLOUDFLARE_API_KEY" \\
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# --- Create or Update record with proxied true ---
RECORD_PAYLOAD="{\"type\":\"A\",\"name\":\"\$FQDN\",\"content\":\"\$IP\",\"ttl\":120,\"proxied\":\${PROXIED}}"

if [[ -n "\$EXISTING_RECORD_ID" && "\$EXISTING_RECORD_ID" != "null" ]]; then
  RESPONSE=\$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/\${ZONE_ID}/dns_records/\${EXISTING_RECORD_ID}" \\
    -H "X-Auth-Email: \$CLOUDFLARE_EMAIL" \\
    -H "X-Auth-Key: \$CLOUDFLARE_API_KEY" \\
    -H "Content-Type: application/json" \\
    --data "\$RECORD_PAYLOAD")
  ACTION="updated"
else
  RESPONSE=\$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/\${ZONE_ID}/dns_records" \\
    -H "X-Auth-Email: \$CLOUDFLARE_EMAIL" \\
    -H "X-Auth-Key: \$CLOUDFLARE_API_KEY" \\
    -H "Content-Type: application/json" \\
    --data "\$RECORD_PAYLOAD")
  ACTION="created"
fi

if echo "\$RESPONSE" | jq -e '.success' | grep -q true; then
  echo "[dns-helper] ✅ DNS record \$ACTION: \${FQDN} → \${IP} (proxied)"
else
  echo "[dns-helper] ❌ Failed to create/update DNS record:"
  echo "\$RESPONSE" | jq
fi
EOF

chmod +x /opt/dns-helper.sh
echo -e "$PREFIX ✅ DNS helper ready: /opt/dns-helper.sh"


# --- Deploy Traefik ---
mkdir -p /opt/traefik
touch /opt/traefik/acme.json
chmod 600 /opt/traefik/acme.json

# --- Dynamic Config ---
cat <<EOF > /opt/traefik/traefik_dynamic.yml
http:
  middlewares:
    globalHeaders:
      headers:
        customRequestHeaders:
          X-Forwarded-Host: "dockflare.${CF_ZONE}"
        customResponseHeaders:
          X-Powered-By: "DockFlareEZ"
        frameDeny: true
        sslRedirect: true
        stsIncludeSubdomains: true
        stsSeconds: 31536000

    secureHeaders:
      headers:
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "strict-origin-when-cross-origin"
        permissionsPolicy: "camera=(), microphone=(), geolocation=()"

    robotHeaders:
      headers:
        customResponseHeaders:
          X-Robots-Tag: "noindex, nofollow"

    cloudflarewarp:
      ipWhiteList:
        sourceRange:
          - "103.21.244.0/22"
          - "103.22.200.0/22"
          - "103.31.4.0/22"
          - "104.16.0.0/13"
          - "104.24.0.0/14"
          - "108.162.192.0/18"
          - "131.0.72.0/22"
          - "141.101.64.0/18"
          - "162.158.0.0/15"
          - "172.64.0.0/13"
          - "173.245.48.0/20"
          - "188.114.96.0/20"
          - "190.93.240.0/20"
          - "197.234.240.0/22"
          - "198.41.128.0/17"
EOF

# --- Compose File ---
cat <<EOF > /opt/traefik/docker-compose.yml
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
    restart: unless-stopped
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--providers.docker=true"
      - "--providers.file.filename=/etc/traefik/traefik_dynamic.yml"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.cloudflare.acme.email=${CFEMAIL}"
      - "--certificatesresolvers.cloudflare.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    environment:
      CLOUDFLARE_EMAIL: "${CFEMAIL}"
      CLOUDFLARE_API_KEY: "${CFAPIKEY}"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./acme.json:/letsencrypt/acme.json
      - ./traefik_dynamic.yml:/etc/traefik/traefik_dynamic.yml
    networks:
      - dockflare

networks:
  dockflare:
    external: true
EOF

# --- Launch Traefik ---
docker network create dockflare > /dev/null 2>&1 || true
cd /opt/traefik && docker compose up -d && TRAEFIK_OK=true
echo -e "$PREFIX 🚦 Traefik deployed."

# --- Deploy Portainer ---
mkdir -p /opt/portainer

cat <<EOF > /opt/portainer/docker-compose.yml
services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    restart: unless-stopped
    labels:
      com.github.saltbox.saltbox_managed: true
      traefik.enable: true

      # HTTP Router (redirect to HTTPS)
      traefik.http.routers.portainer-http.entrypoints: web
      traefik.http.routers.portainer-http.rule: Host(\`portainer.${CF_ZONE}\`)
      traefik.http.routers.portainer-http.middlewares: globalHeaders@file,redirect-to-https@docker,robotHeaders@file,cloudflarewarp@docker
      traefik.http.routers.portainer-http.service: portainer

      # HTTPS Router
      traefik.http.routers.portainer.entrypoints: websecure
      traefik.http.routers.portainer.rule: Host(\`portainer.${CF_ZONE}\`)
      traefik.http.routers.portainer.middlewares: globalHeaders@file,secureHeaders@file,robotHeaders@file,cloudflarewarp@docker
      traefik.http.routers.portainer.tls.certresolver: cloudflare
      traefik.http.routers.portainer.tls.options: securetls@file
      traefik.http.routers.portainer.service: portainer

      # Internal port used by Portainer
      traefik.http.services.portainer.loadbalancer.server.port: 9000

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

read -p "$(echo -e "$PREFIX 🌐 Create Cloudflare DNS record for Portainer? (y/n): ")" ADD_PORTAINER_DNS
if [[ "$ADD_PORTAINER_DNS" =~ ^[Yy]$ ]]; then
  export CLOUDFLARE_EMAIL="$CFEMAIL"
  export CLOUDFLARE_API_KEY="$CFAPIKEY"
  /opt/dns-helper.sh portainer "$CF_ZONE" "$VPS_IP"
else
  echo -e "$PREFIX ⚠️ Skipping DNS record creation for Portainer."
fi

# --- Summary Report ---
echo -e "\n${ORANGE}========== SETUP SUMMARY ==========${RESET}"
echo -e "$PREFIX System update:        $([ "$UPDATE_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Cloudflare verified:  $([ "$CF_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX DNS test passed:      $([ "$DNS_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX User created:         $([ "$USER_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Docker installed:     $([ "$DOCKER_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Traefik running:      $([ "$TRAEFIK_OK" = true ] && echo ✅ || echo ❌)"
echo -e "$PREFIX Portainer running:    $([ "$PORTAINER_OK" = true ] && echo ✅ || echo ❌)"

echo -e "\n${GREEN}Done! Your VPS is ready. SSH login: ssh -p $SSHPORT $NEWUSER@$VPS_IP${RESET}"
echo -e "${GREEN}Temporary password: $USERPASS${RESET}"

# --- Reboot Prompt ---
echo -e "\n$PREFIX ⚠️  Please make sure you have copied the new SSH port and temporary password above."
read -p "$(echo -e "$PREFIX Do you want to reboot now to apply changes? (y/n): ")" FINALREBOOT
if [[ "$FINALREBOOT" =~ ^[Yy]$ ]]; then
  echo -e "$PREFIX 🔁 Rebooting now..."
  reboot
else
  echo -e "$PREFIX 🚫 Reboot skipped. You can reboot manually later."
fi
