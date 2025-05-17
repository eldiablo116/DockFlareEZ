#!/bin/bash

echo "==============================="
echo "   DockFlare EZSetup v1.6"
echo "==============================="
echo ""

# 0. Check for system updates before proceeding
echo "🔍 Checking for available updates..."
apt update -qq > /dev/null

UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

if [ "$UPGRADABLE" -gt 0 ]; then
  echo "🔄 Updates available for your system."
  read -p "Would you like to install updates now? (y/n): " DOUPGRADE
  if [[ "$DOUPGRADE" =~ ^[Yy]$ ]]; then
    echo "⬇️ Installing updates..."
    apt upgrade -y

    # Recheck upgradable list after upgrade
    POSTUPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

    if [ "$POSTUPGRADABLE" -eq 0 ]; then
      echo ""
      read -p "Updates installed. Would you like to reboot now? (y/n): " REBOOTAFTERUPGRADE
      if [[ "$REBOOTAFTERUPGRADE" =~ ^[Yy]$ ]]; then
        echo "🔁 Rebooting now. Please re-run this script after your server comes back online."
        reboot
        exit 0
      else
        echo "⚠️ Please reboot manually and then re-run this script."
        exit 0
      fi
    else
      echo ""
      echo "✅ System upgraded. Some updates were deferred by Ubuntu's phased rollout."
      echo "No reboot required. Continuing with DockFlareEZsetup..."
      echo ""
    fi
  fi
else
  echo "✅ Great! No packages need upgrading."
fi

# Ask for essential inputs only
read -p "Enter a new admin username: " NEWUSER
read -p "Enter your Cloudflare email: " CFEMAIL
read -p "Enter your Cloudflare API token: " CFTOKEN
read -p "Enter your domain (e.g., example.com): " DOMAIN

# Generate a random safe SSH port
SSHPORT=$(shuf -i 2000-65000 -n 1)
echo "📦 SSH will be set to port: $SSHPORT"

echo ""
echo "Setting up system... please wait."

# 1. Create a new sudo user
adduser --disabled-password --gecos "" "$NEWUSER"
usermod -aG sudo "$NEWUSER"

# 2. Choose SSH login method
read -p "Would you like to set up SSH key login for the new user? (y/n): " SETUPKEYS

if [[ "$SETUPKEYS" =~ ^[Yy]$ ]]; then
  mkdir -p /home/$NEWUSER/.ssh
  cp ~/.ssh/authorized_keys /home/$NEWUSER/.ssh/
  chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.ssh
  chmod 700 /home/$NEWUSER/.ssh
  chmod 600 /home/$NEWUSER/.ssh/authorized_keys
  SSH_METHOD="key"
  echo "✅ SSH key login configured for user '$NEWUSER'."
else
  SSH_METHOD="password"
  echo "⚠️ SSH key setup skipped. Enabling password login..."

  # Generate a random 16-character password
  USERPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

  echo "$NEWUSER:$USERPASS" | chpasswd

  # Enable password login in SSH
  sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
  sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
fi

# 3. Harden SSH (leave root login enabled)
sed -i "s/#Port 22/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/Port .*/Port $SSHPORT/" /etc/ssh/sshd_config
systemctl restart sshd

# 4. Install Docker & Compose plugin
apt install -y ca-certificates curl gnupg lsb-release docker.io docker-compose-plugin

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

# 9. Done + tailored final instructions
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
  echo ""
  echo "User's authorized_keys: /home/$NEWUSER/.ssh/authorized_keys"
else
  echo ""
  echo "🔑 SSH password login enabled for $NEWUSER."
  echo "Reconnect using:"
  echo "  ssh -p $SSHPORT $NEWUSER@your-server-ip"
  echo ""
  echo "Temporary generated password:"
  echo "  $USERPASS"
  echo "⚠️  Change this password after login using 'passwd'."
fi

echo ""
read -p "Would you like to reboot now to apply all changes (y/n)? " REBOOTANSWER
if [[ "$REBOOTANSWER" =~ ^[Yy]$ ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Reboot skipped. It's recommended to reboot manually before using Docker as the new user."
fi
#!/bin/bash

echo "==============================="
echo "   DockFlare EZSetup v1.6"
echo "==============================="
echo ""

# 0. Check for system updates before proceeding
echo "🔍 Checking for available updates..."
apt update -qq > /dev/null

UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

if [ "$UPGRADABLE" -gt 0 ]; then
  echo "🔄 Updates available for your system."
  read -p "Would you like to install updates now? (y/n): " DOUPGRADE
  if [[ "$DOUPGRADE" =~ ^[Yy]$ ]]; then
    echo "⬇️ Installing updates..."
    apt upgrade -y

    # Recheck upgradable list after upgrade
    POSTUPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

    if [ "$POSTUPGRADABLE" -eq 0 ]; then
      echo ""
      read -p "Updates installed. Would you like to reboot now? (y/n): " REBOOTAFTERUPGRADE
      if [[ "$REBOOTAFTERUPGRADE" =~ ^[Yy]$ ]]; then
        echo "🔁 Rebooting now. Please re-run this script after your server comes back online."
        reboot
        exit 0
      else
        echo "⚠️ Please reboot manually and then re-run this script."
        exit 0
      fi
    else
      echo ""
      echo "✅ System upgraded. Some updates were deferred by Ubuntu's phased rollout."
      echo "No reboot required. Continuing with DockFlareEZsetup..."
      echo ""
    fi
  fi
else
  echo "✅ Great! No packages need upgrading."
fi

# Ask for essential inputs only
read -p "Enter a new admin username: " NEWUSER
read -p "Enter your Cloudflare email: " CFEMAIL
read -p "Enter your Cloudflare API token: " CFTOKEN
read -p "Enter your domain (e.g., example.com): " DOMAIN

# Generate a random safe SSH port
SSHPORT=$(shuf -i 2000-65000 -n 1)
echo "📦 SSH will be set to port: $SSHPORT"

echo ""
echo "Setting up system... please wait."

# 1. Create a new sudo user
adduser --disabled-password --gecos "" "$NEWUSER"
usermod -aG sudo "$NEWUSER"

# 2. Choose SSH login method
read -p "Would you like to set up SSH key login for the new user? (y/n): " SETUPKEYS

if [[ "$SETUPKEYS" =~ ^[Yy]$ ]]; then
  mkdir -p /home/$NEWUSER/.ssh
  cp ~/.ssh/authorized_keys /home/$NEWUSER/.ssh/
  chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.ssh
  chmod 700 /home/$NEWUSER/.ssh
  chmod 600 /home/$NEWUSER/.ssh/authorized_keys
  SSH_METHOD="key"
  echo "✅ SSH key login configured for user '$NEWUSER'."
else
  SSH_METHOD="password"
  echo "⚠️ SSH key setup skipped. Enabling password login..."

  # Generate a random 16-character password
  USERPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

  echo "$NEWUSER:$USERPASS" | chpasswd

  # Enable password login in SSH
  sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
  sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
fi

# 3. Harden SSH (leave root login enabled)
sed -i "s/#Port 22/Port $SSHPORT/" /etc/ssh/sshd_config
sed -i "s/Port .*/Port $SSHPORT/" /etc/ssh/sshd_config
systemctl restart sshd

# 4. Install Docker & Compose plugin
apt install -y ca-certificates curl gnupg lsb-release docker.io docker-compose-plugin

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

# 9. Done + tailored final instructions
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
  echo ""
  echo "User's authorized_keys: /home/$NEWUSER/.ssh/authorized_keys"
else
  echo ""
  echo "🔑 SSH password login enabled for $NEWUSER."
  echo "Reconnect using:"
  echo "  ssh -p $SSHPORT $NEWUSER@your-server-ip"
  echo ""
  echo "Temporary generated password:"
  echo "  $USERPASS"
  echo "⚠️  Change this password after login using 'passwd'."
fi

echo ""
read -p "Would you like to reboot now to apply all changes (y/n)? " REBOOTANSWER
if [[ "$REBOOTANSWER" =~ ^[Yy]$ ]]; then
  echo "Rebooting..."
  reboot
else
  echo "Reboot skipped. It's recommended to reboot manually before using Docker as the new user."
fi
