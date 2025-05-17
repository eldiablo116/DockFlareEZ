#!/bin/bash

# --- Colors ---
BLUE='\e[34m'
ORANGE='\e[38;5;208m'
GREEN='\e[32m'
RESET='\e[0m'

# --- Branding ---
PREFIX="$(echo -e "${BLUE}[Dock${ORANGE}Flare${GREEN}EZ${RESET}]")"
echo -e "${ORANGE}===============================\n   DockFlare EZSetup v2.8\n===============================${RESET}\n"


    sleep 2
  done

  if ! ping -c 1 "$TEST_SUBDOMAIN.$CF_ZONE" &>/dev/null; then
    echo -e "$PREFIX ❌ DNS did not propagate in time."
    echo -e "$PREFIX Please check DNS propagation or record creation permissions."
    exit 1
  fi
fi
fi

# --- Update Check ---

# --- Cloudflare API validation ---
echo -e "$PREFIX Validating Cloudflare API credentials..."

CF_ZONE=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
CF_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ "$CF_ZONE_ID" == "null" || -z "$CF_ZONE_ID" ]]; then
  echo -e "$PREFIX ❌ Failed to verify Cloudflare API credentials or domain ($CF_ZONE)."
  echo -e "$PREFIX Please ensure the token has zone.read and zone.dns permissions."
  exit 1
else
  echo -e "$PREFIX ✅ Cloudflare API verified. Zone ID: $CF_ZONE_ID"

  # Create a temporary subdomain record
  TEST_SUBDOMAIN="dockflareez-test-$(shuf -i 1000-9999 -n 1)"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CFTOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'$TEST_SUBDOMAIN'.'$CF_ZONE'","content":"'$(curl -s ifconfig.me)'","ttl":120,"proxied":false}' > /dev/null

  echo -e "$PREFIX 🕵️ Created test DNS record: $TEST_SUBDOMAIN.$CF_ZONE"
  echo -e "$PREFIX ⏳ Waiting for DNS propagation..."

  for i in {1..30}; do
    if ping -c 1 "$TEST_SUBDOMAIN.$CF_ZONE" &>/dev/null; then
      echo -e "$PREFIX ✅ DNS record resolved successfully!"
      break
    fi
    sleep 2
  done

  if ! ping -c 1 "$TEST_SUBDOMAIN.$CF_ZONE" &>/dev/null; then
    echo -e "$PREFIX ❌ DNS did not propagate in time."
    echo -e "$PREFIX Please check DNS propagation or record creation permissions."
    exit 1
  fi

  # Delete the temporary DNS record
  RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$TEST_SUBDOMAIN.$CF_ZONE" \
    -H "Authorization: Bearer $CFTOKEN" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [[ -n "$RECORD_ID" && "$RECORD_ID" != "null" ]]; then
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
      -H "Authorization: Bearer $CFTOKEN" \
      -H "Content-Type: application/json" > /dev/null
    echo -e "$PREFIX 🧹 Cleaned up test DNS record."
  fi
fi

echo -e "$PREFIX \U1F50D Checking for updates..."
apt update -qq > /dev/null
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)

if [ "$UPGRADABLE" -gt 0 ]; then
  echo -e "$PREFIX \U1F504 Updates available."
  read -p "$(echo -e "$PREFIX Install updates now? (y/n): ")" DOUPGRADE
  if [[ "$DOUPGRADE" =~ ^[Yy]$ ]]; then
    echo -e "$PREFIX \U2B07\UFE0F Installing updates..."
    UPGRADE_OUTPUT=$(apt upgrade -y -qq)
    if echo "$UPGRADE_OUTPUT" | grep -q "0 upgraded"; then
      echo -e "$PREFIX \xE2\x9C\x85 No updates applied (phased)."
    else
      read -p "$(echo -e "$PREFIX Reboot now to finish updates? (y/n): ")" REBOOTAFTERUPGRADE
      if [[ "$REBOOTAFTERUPGRADE" =~ ^[Yy]$ ]]; then
        echo -e "$PREFIX \U1F501 Rebooting. Re-run script after restart."
        reboot
        exit 0
      else
        echo -e "$PREFIX ⚠️ Reboot manually later."
        exit 0
      fi
    fi
  fi
else
  echo -e "$PREFIX \xE2\x9C\x85 System is up to date."
fi

# --- User Input ---
read -p "$(echo -e "$PREFIX Enter new admin username: ")" NEWUSER
read -p "$(echo -e "$PREFIX Cloudflare email: ")" CFEMAIL
read -p "$(echo -e "$PREFIX Cloudflare API token: ")" CFTOKEN
read -p "$(echo -e "$PREFIX Your domain (e.g., example.com): ")" DOMAIN

# --- Random SSH Port ---
SSHPORT=$(shuf -i 2000-65000 -n 1)
echo -e "$PREFIX \U1F4E6 SSH port: $SSHPORT"

# --- Create user ---

# --- Create DNS record for Portainer ---
PORTAINER_SUBDOMAIN="portainer.$CF_ZONE"
VPS_IP=$(curl -s ifconfig.me)

# Check if record exists
RECORD_CHECK=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$PORTAINER_SUBDOMAIN" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json")

EXISTING_RECORD_ID=$(echo "$RECORD_CHECK" | jq -r '.result[0].id')
EXISTING_IP=$(echo "$RECORD_CHECK" | jq -r '.result[0].content')

if [[ "$EXISTING_RECORD_ID" == "null" || -z "$EXISTING_RECORD_ID" ]]; then
  echo -e "$PREFIX Creating A record for Portainer: $PORTAINER_SUBDOMAIN -> $VPS_IP"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CFTOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'$PORTAINER_SUBDOMAIN'","content":"'$VPS_IP'","ttl":120,"proxied":false}' > /dev/null
else
  if [[ "$EXISTING_IP" != "$VPS_IP" ]]; then
    echo -e "$PREFIX Updating A record for Portainer: $PORTAINER_SUBDOMAIN -> $VPS_IP"
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$EXISTING_RECORD_ID" \
      -H "Authorization: Bearer $CFTOKEN" \
      -H "Content-Type: application/json" \
      --data '{"type":"A","name":"'$PORTAINER_SUBDOMAIN'","content":"'$VPS_IP'","ttl":120,"proxied":false}' > /dev/null
  else
    echo -e "$PREFIX DNS record for Portainer already up-to-date: $PORTAINER_SUBDOMAIN -> $VPS_IP"
  fi
fi

adduser --disabled-password --gecos "" "$NEWUSER" > /dev/null
usermod -aG sudo "$NEWUSER"
touch "/home/$NEWUSER/.Xauthority"
chown $NEWUSER:$NEWUSER "/home/$NEWUSER/.Xauthority"
echo -e "$PREFIX User '$NEWUSER' created, Xauthority added.. OK!"

# --- SSH Setup ---
SSH_METHOD="password"
USERPASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
echo "$NEWUSER:$USERPASS" | chpasswd
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
echo -e "$PREFIX Password login enabled for '$NEWUSER'.. OK!"
  sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
  echo -e "$PREFIX Password login enabled.. OK!"
fi
