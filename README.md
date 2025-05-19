<p align="center">
  <img src="https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/assets/logo_transparent.png" alt="DockFlareEZ Logo" width="200" />
</p>

<h1 align="center">🚀 DockFlareEZ</h1>
<p align="center">Your zero-hassle VPS bootstrapper for Docker, Traefik, Portainer & Cloudflare DNS automation.</p>

---

## ✅ One-Line Install

SSH into your **fresh Ubuntu VPS** as `root` and run:

```bash
bash <(curl -s https://raw.githubusercontent.com/eldiablo116/DockFlareEZ-/main/DockFlareEZsetup.sh)
```

---

## 🧩 What You'll Need

1. **Cloudflare Account** managing your domain  
   → https://dash.cloudflare.com

2. **Cloudflare Global API Key** (not token)
   - Find it under: https://dash.cloudflare.com/profile/api-tokens

3. **A Domain**

---

## 🛠️ What It Installs

| Component     | Description |
|---------------|-------------|
| 🔐 Random SSH Port | Disables default port 22, strong password auth only |
| 👤 New Admin User | Sudo-enabled, with no-password sudo |
| 🐳 Docker & Compose | Latest stable versions |
| 🌐 Traefik | With Let's Encrypt SSL via Cloudflare DNS-01 |
| 📦 Portainer | Accessible securely via Traefik |
| 🌍 DNS Helper | Auto-creates DNS records for deployed apps |
| 🧭 MOTD Branding | Shows domain, public IP & `df` command list |

---

## 💻 Included CLI Tools

All tools install to `/usr/local/bin/` and work globally.

### 🧰 `dfapps`
> Interactive menu to deploy prebuilt Docker apps.

```bash
dfapps
```

- Prompts you to select an app
- Auto-generates subdomain (e.g. `uptime-kuma-2374.yourdomain.com`)
- Pulls template from GitHub
- Deploys app via Docker Compose
- Auto-creates Cloudflare DNS record

### 🧾 `dfconfig`
> View and edit stored Cloudflare credentials.

```bash
dfconfig
```

- Shows current values (with masked API key)
- Prompts to update them if needed
- Updates your `.bashrc` environment for future sessions

### 🚀 `dfdeploy`
> Deploy any `docker-compose.yml` in your current directory and auto-create DNS.

```bash
cd /opt/containers/myapp
dfdeploy
```

- Looks for `Host("sub.domain.com")` rule
- Detects subdomain + domain from Compose file
- Creates matching DNS A record via Cloudflare

### 🔄 `dfupdate`
> Update all DockFlareEZ CLI tools.

```bash
dfupdate
```

- Checks for latest versions of:
  - `dfapps`
  - `dfdeploy`
  - `dfconfig`
  - `dfupdate` itself
- Compares local version
- Prompts to upgrade individually

---

## 📦 App Template Format

Each app is stored in GitHub as a standalone `.sh` installer in `/dfapps`.

To build your own:
- Use subdomain placeholder `{{SUBDOMAIN}}`
- Use domain placeholder `{{DOMAIN}}`
- Optional envs: `{{ADMIN_USER}}`, `{{ADMIN_PASS}}`

Example (inside your template):

```yaml
traefik.http.routers.myapp.rule: 'Host("{{SUBDOMAIN}}.{{DOMAIN}}")'
```

---

## 🔐 Security Features

- SSH locked to random port
- Root login remains enabled (for recovery)
- No sudo password prompt for the created user
- Docker group access granted to admin user
- DNS validation test ensures propagation works before SSL issuance

---

## 📣 MOTD Branding

After setup, your server will show this on login:

```
🧭  Powered by DockFlareEZ

🌐 Domain: yourdomain.com
📡 Public IP: 1.2.3.4

💡 Commands:
  👉  dfapps     - Launch interactive app installer
  👉  dfconfig   - View or update Cloudflare DNS settings
  👉  dfdeploy   - Deploy + auto-DNS any docker-compose app
  👉  dfupdate   - Update all DockFlareEZ utilities

Happy deploying! 🚀
```

---

## ♻️ Uninstall

To fully remove all components (Docker, Portainer, Traefik, DNS helpers):

```bash
dfuninstall
```

> ⚠️ This will reset your SSH port to 22 and wipe all installed services (except the user account).

---

## 🤝 Contributing

PRs welcome at https://github.com/eldiablo116/DockFlareEZ-  
Ideas? Drop them as GitHub Issues.

---

©️ 2025 – eldiablo116 – DockFlareEZ is free and open source.
