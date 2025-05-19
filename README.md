<p align="center">
  <img src="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/assets/logo_transparent.png" alt="DockFlareEZsetup Logo" width="200" />
</p>

<h1 align="center">🚀 DockFlareEZsetup</h1>
<p align="center">One-line VPS bootstrapper for Docker + Traefik + Cloudflare DNS + Portainer</p>

---

## ✅ One-Line Install

SSH into your fresh Ubuntu VPS as **root**, then run:

```bash
bash <(curl -s https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/DockFlareEZsetup.sh)
```

---

## 🔧 What You'll Need Before You Begin

1. **A Cloudflare account** managing your domain  
   → <a href="https://dash.cloudflare.com" target="_blank">https://dash.cloudflare.com</a>

2. **Your Cloudflare Global API Key**
   - Found at: <a href="https://dash.cloudflare.com/profile" target="_blank">Cloudflare Profile</a>
   - Not a token — use the Global API Key

---

## 🛠️ What This Script Does

- Verifies your Cloudflare credentials
- Creates a test subdomain and confirms DNS propagation
- Creates a new sudo-enabled user with a random secure password
- Randomly selects a secure SSH port and enables password login
- Installs Docker and the Docker Compose plugin
- Deploys **Traefik** with:
  - Cloudflare DNS-01 SSL certificate automation
  - Auto HTTPS via Let's Encrypt
- Deploys **Portainer** at a randomized subdomain like `https://portainer-5732.yourdomain.com`
- Creates:
  - `/opt/traefik/` → Traefik config + certs
  - `/opt/portainer/` → Portainer container config
  - `/opt/dns-helper.sh` → Script to create DNS records for any subdomain
  - `dockflare` Docker network (shared by future containers)
- Adds the `dcud` command (Docker Compose Up + DNS):
  - Automatically creates Cloudflare DNS records when deploying any service that uses a `Host("...")` Traefik rule

---

## 🔁 After Installation

You’ll see your generated SSH port and user credentials at the end:

```bash
ssh -p YOURPORT youruser@your-server-ip
```

Then visit your Portainer instance at a URL like:

```
https://portainer-4382.yourdomain.com
```

> The exact subdomain is randomly generated to avoid Let's Encrypt rate limits.

---

## 🌐 Deploying New Services with Auto-DNS

Use the `dcud` command to deploy any new Docker Compose app and automatically generate a matching Cloudflare DNS record:

```bash
cd /opt/my-new-app
dcud
```

> `dcud` looks for a `Host("sub.domain")` rule inside `docker-compose.yml`, then creates the matching A record in Cloudflare pointing to your VPS.

---

## 🐳 Example: Add a New Container

```yaml
services:
  myapp:
    image: yourimage
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(\"app.yourdomain.com\")"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
    networks:
      - dockflare

networks:
  dockflare:
    external: true
```

Place your app folder anywhere (e.g. `/opt/containers/myapp`) and run:

```bash
cd /opt/containers/myapp
dcud
```

---

## 🔒 Security Notes

- SSH is locked to a random high port
- Only password login is enabled by default (no key requirement)
- Cloudflare proxy + Let's Encrypt SSL via DNS challenge
- All public endpoints are HTTPS-secured behind Traefik

---

## 💡 Built For

- Anyone tired of repeating container + DNS setup manually

---

## 🤝 Contributing

Suggestions and PRs welcome! Want to add app templates, compose helpers, or upstream tool integrations? Go for it.

---

©️ 2025 – eldiablo116 – Built for fast, secure, repeatable VPS launches.
