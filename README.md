<p align="center">
  <img src="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/assets/logo_transparent.png" alt="DockFlareEZsetup Logo" width="200" />
</p>

<h1 align="center">🚀 DockFlareEZsetup</h1>
<p align="center">One-line VPS bootstrapper for Docker + Traefik + Cloudflare DNS</p>

---

## ✅ One-Line Install

SSH into your fresh Ubuntu VPS as **root**, then run:

```bash
bash <(curl -s https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/DockFlareEZsetup.sh)
```

---

## 🔧 What You'll Need Before You Begin

1. **A Cloudflare account** managing your domain  
   → [https://dash.cloudflare.com](https://dash.cloudflare.com)

2. **A Cloudflare API Token**
   - Go to: [Create an API Token](https://dash.cloudflare.com/profile/api-tokens)
   - Use the **"Edit zone DNS"** template
   - Scope: your domain only

3. **A domain** (e.g. `example.com`) pointing to your VPS
   - Add an `A` or `CNAME` record in Cloudflare DNS
   - You can leave the orange cloud (proxy) **ON**

4. **(Optional) Your public SSH key**
   - The script gives you the option to use SSH key or password login

---

## 🛠️ What This Script Does

- Creates a new sudo-enabled user
- Randomly selects a secure SSH port
- Lets you choose SSH key login or password-based login
- Installs Docker and Docker Compose plugin
- Deploys **Traefik** with:
  - Cloudflare DNS-01 SSL certificate automation
  - Auto HTTPS via Let's Encrypt
- Creates:
  - `/opt/traefik/` → contains Traefik config + certs
  - `/opt/containers/` → your apps go here
  - Docker network: `dockflare`

---

## 🔁 After Installation

You’ll see your generated SSH port at the end and either:

🔐 If using SSH key login:
```bash
ssh -p YOURPORT youruser@your-server-ip
```

🔑 If using password login:
```bash
ssh -p YOURPORT youruser@your-server-ip
# Password will be shown at the end of the script
```

---

## 🐳 Add New Containers

Here’s an example of how to add a service later:

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

---

## 🔒 Security Notes

- SSH is locked to a random high port
- SSH password login is only enabled if you ask for it
- Let's Encrypt SSL via Cloudflare DNS (no open port 80 required)

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

©️ 2024 – eldiablo116 – Built for fast, secure, repeatable VPS launches.
