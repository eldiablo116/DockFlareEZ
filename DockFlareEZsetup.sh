#!/bin/bash

echo "==============================="
echo "   DockFlare EZSetup v1.2"
echo "==============================="
echo ""

# Ask for inputs
read -p "Enter a new admin username: " NEWUSER
echo "⚠️  Choose a non-standard SSH port between 1024 and 65535 to improve security."
read -p "Enter new SSH port (e.g., 2222): " SSHPORT
read -p "Enter your Cloudflare email: " CFEMAIL
read -p "Enter your Cloudflare API token: " CFTOKEN
read -p "Enter your domain (e.g., example.com): " DOMAIN

echo ""
echo "Setting up system... please wait."

# 1. Create a new sudo user
adduser --disabled-password --gecos "" "$NEWUSER"
usermod -aG sudo "$NEWUSER"

# 2. Add SSH key access for the new user (assumes root has key auth already)
mkdir -p /home/$NEWUSER/.ssh
cp ~/.ssh/authorized_keys /home/$NEWUSER/.ssh/
chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.ssh
chmod 700 /home/$NEWUSER/.ssh
chmod 600 /home/$NEWUSER/.ssh/authorized_keys

# 3. Harden SSH (keep root login enabled)
sed -i "s/#Port 22/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/Port .*/Port $SSHPORT/" /etc/ssh/sshd_config
# sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart sshd

# 4. Install Docker & Docker Compose plugin
apt update && apt install -y \
  ca-certificates curl gnupg lsb-release docker.io docker-compose-plugin

systemctl enable docker
usermod -aG docker $NEWUSER

# 5. Prepare folder structure
mkdir -p /opt/traefik
mkdir -p /opt/containers
touch /opt/traefik/acme.json
chmod 600 /opt/traefik/acme.json

# 6. Generate Docker Compose for Traefik
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

# 7. Create the external Docker network
docker network create dockflare || true

# 8. Launch Traefik
cd /opt/traefik
docker compose up -d

# 9. Done + Reminders + Reboot Prompt
echo ""
echo "==========================================="
echo "✅ DockFlareEZsetup is complete!"
echo ""
echo "• SSH is now set to port $SSHPORT for user '$NEWUSER'"
echo "• Traefik is live with Cloudflare DNS support"
echo "• Add containers in /opt/containers and join 'dockflare' network"
echo ""
echo "==========================================="
echo "IMPORTANT:"
echo "To reconnect after reboot, use:"
echo "  ssh -p $SSHPORT $NEWUSER@your-server-ip"
echo "==========================================="
echo ""

read -p "Would you like to reboot now to apply all changes (y/n)? " REBOOTANSWER
if [[ "$REBOOTANSWER" =~ ^[Yy]$ ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Reboot skipped. It's recommended to reboot manually before using Docker as the new user."
fi
