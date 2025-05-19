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

2. **A Cloudflare API Token**
   - Go to: <a href="https://dash.cloudflare.com/profile/api-tokens" target="_blank">Create an API Token</a>
   - Use the **"Edit zone DNS"** template
   - Required permissions:
     - Zone:DNS → Edit
     - Zone:Zone → Read

3. **A domain** (e.g. `example.com`) pointing to your VPS
   - Add an `A` record in Cloudflare DNS to your VPS public IP
   - You can leave the orange cloud (proxy) **ON**

---

## 🛠️ What This Script Does

- Verifies your Cloudflare API credentials
- Creates a test subdomain and confirms DNS propagation
- Creates a new sudo-enabled user
- Randomly selects a secure SSH port
- Always uses password-based login (no SSH key prompt)
- Installs Docker and the Docker Compose plugin
- Deploys **Traefik** with:
  - Cloudflare DNS-01 SSL certificate automation
  - Auto HTTPS via Let's Encrypt
- Deploys **Portainer** at `https://portainer.yourdomain.com` via Traefik
- Creates:
  - `/opt/traefik/` → Traefik config + certs
  - `/opt/portainer/` → Portainer container config
  - `/opt/containers/` → where you can add more apps
  - Docker network: `dockflare`

---

## 🔁 After Installation

You’ll see your generated SSH port at the end and:

```bash
ssh -p YOURPORT youruser@your-server-ip
# Password will be shown at the end of the script
```

Then visit:

```
https://portainer.yourdomain.com
```

---

## 🐳 Add New Containers

Here's an example of how to add a service later:

```yaml
services:
  myapp:
    image: yourimage
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`app.yourdomain.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
    networks:
      - dockflare

networks:
  dockflare:
    external: true
```

Place new `docker-compose.yml` files under `/opt/containers/` or any directory you wish.

---

## 🔒 Security Notes

- SSH is locked to a random high port
- Password-based login only (no SSH key support)
- Cloudflare DNS + Let's Encrypt for SSL — no exposed port 80 required

---

## 💡 Built For

- Dashboards (Appsmith, Portainer, Grafana)
- Internal APIs
- Dev and staging apps
- Secure edge deployments

---

## 🤝 Contributing

Suggestions and PRs welcome!

---

©️ 2025 – eldiablo116 – Built for fast, secure, repeatable VPS launches.
