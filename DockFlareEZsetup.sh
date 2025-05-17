#!/bin/bash

# Colors
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'

# Prefix & Header
PREFIX="${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]"
echo -e "${ORANGE}===============================\n   DockFlare EZSetup v2.3\n===============================${RESET}\n"

# --- System Update ---
echo -e "$PREFIX 🔍 Checking for available updates..."
apt update -qq > /dev/null
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

if [ "$UPGRADABLE" -gt 0 ]; then
  echo -e "$PREFIX 🔄 Updates available for your system."
  read -p "$(echo -e "$PREFIX Would you like to install updates now? (y/n): ")" DOUPGRADE
  if [[ "$DOUPGRADE" =~ ^[Yy]$ ]]; then
    echo -e "$PREFIX ⬇️ Installing updates..."
    UPGRADE_OUTPUT=$(apt upgrade -y -qq)
    if echo "$UPGRADE_OUTPUT" | grep -q "0 upgraded, 0 newly installed, 0 to remove"; then
      echo -e "$PREFIX ✅ No updates were applied. Some updates may be deferred."
    else
      read -p "$(echo -e "$PREFIX Updates installed. Would you like to reboot now? (y/n): ")" REBOOTAFTERUPGRADE
      if [[ "$REBOOTAFTERUPGRADE" =~ ^[Yy]$ ]]; then
        echo -e "$PREFIX 🔁 Rebooting now. Please re-run this script after reboot."
        reboot
        exit 0
      else
        echo -e "$PREFIX ⚠️ Please reboot manually before running this script again."
        exit 0
      fi
    fi
  fi
else
  echo -e "$PREFIX ✅ Great! No packages need upgrading."
fi

# --- Inputs ---
read -p "$(echo -e "$PREFIX Enter a new admin username: ")" NEWUSER
read -p "$(echo -e "$PREFIX Enter your Cloudflare email: ")" CFEMAIL
read -p "$(echo -e "$PREFIX Enter your Cloudflare API token: ")" CFTOKEN
read -p "$(echo -e "$PREFIX Enter your domain (e.g., example.com): ")" DOMAIN

# Random SSH port
SSHPORT=$(shuf -i 2000-65000 -n 1)
echo -e "$PREFIX 📦 SSH will be set to port: $SSHPORT"

# --- Create user ---
adduser --disabled-password --gecos "" "$NEWUSER" > /dev/null
usermod -aG sudo "$NEWUSER"
mkdir -p /home/$NEWUSER
touch /home/$NEWUSER/.Xauthority
chown $NEWUSER:$NEWUSER /home/$NEWUSER/.Xauthority
echo -e "$PREFIX User '$NEWUSER' created, Xauthority added.. OK!"

# --- SSH Setup ---
read -p "$(echo -e "$PREFIX Would you like to set up SSH key login for the new user? (y/n): ")" SETUPKEYS
if [[ "$SETUPKEYS" =~ ^[Yy]$ ]]; then
  mkdir -p /home/$NEWUSER/.ssh
  cp ~/.ssh/authorized_keys /home/$NEWUSER/.ssh/ 2>/dev/null
  chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.ssh
  chmod 700 /home/$NEWUSER/.ssh
  chmod 600 /home/$NEWUSER/.ssh/authorized_keys
  SSH_METHOD="key"
  echo -e "$PREFIX SSH key login configured for '$NEWUSER'.. OK!"
else
  SSH_METHOD="password"
  USERPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
  echo "$NEWUSER:$USERPASS" | chpasswd
  sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
  sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
  echo -e "$PREFIX Password login enabled for '$NEWUSER'.. OK!"
fi

# --- SSH Port ---
sed -i "s/#Port 22/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/Port .*/Port $SSHPORT/" /etc/ssh/sshd_config
systemctl restart ssh || systemctl restart ssh.service
echo -e "$PREFIX SSH port changed to $SSHPORT and SSH restarted.. OK!"

# --- Install Docker ---
echo -e "$PREFIX Installing Docker and Compose..."
apt install -y -qq ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common > /dev/null
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update -qq > /dev/null
apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
systemctl enable docker > /dev/null
usermod -aG docker $NEWUSER
echo -e "$PREFIX Docker installed and user added to docker group.. OK!"

# --- Directories ---
mkdir -p /opt/traefik
mkdir -p /opt/containers
touch /opt/traefik/acme.json
chmod 600 /opt/traefik/acme.json
echo -e "$PREFIX Folder structure created.. OK!"

# --- Traefik Docker Compose ---
cat <<EOF > /opt/traefik/docker-compose.yml
version: "3.8"
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
    restart: unless-stopped
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
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
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./acme.json:/letsencrypt/acme.json"
    networks:
      - dockflare

networks:
  dockflare:
    external: true
EOF

docker network create dockflare > /dev/null 2>&1 || true
cd /opt/traefik && docker compose up -d > /dev/null
echo -e "$PREFIX Traefik container and network launched.. OK!"

# --- Final Message ---
echo ""
echo "==========================================="
echo "✅ DockFlareEZsetup is complete!"
echo ""
echo "• SSH is now set to port $SSHPORT for user '$NEWUSER'"
echo "• Traefik is live with Cloudflare DNS support"
echo "• Add containers in /opt/containers and join 'dockflare' network"
echo "==========================================="

if [[ "$SSH_METHOD" == "key" ]]; then
  echo ""
  echo "🔐 SSH key login enabled for $NEWUSER."
  echo "Reconnect using:"
  echo "  ssh -p $SSHPORT $NEWUSER@your-server-ip"
else
  echo ""
  echo "🔑 SSH password login enabled for $NEWUSER."
  echo "Reconnect using:"
  echo "  ssh -p $SSHPORT $NEWUSER@your-server-ip"
  echo ""
  echo "Temporary password:"
  echo "  $USERPASS"
  echo "⚠️  Change this password after login using 'passwd'."
fi

echo ""
read -p "$(echo -e "$PREFIX Would you like to reboot now to apply all changes (y/n)? ")" REBOOTANSWER
if [[ "$REBOOTANSWER" =~ ^[Yy]$ ]]; then
  echo -e "$PREFIX Rebooting..."
  reboot
else
  echo -e "$PREFIX Reboot skipped. It's recommended to reboot manually before using Docker as the new user."
fi
