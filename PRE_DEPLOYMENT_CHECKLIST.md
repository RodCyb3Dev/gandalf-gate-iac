# 🚀 Pre-Deployment Checklist

Complete this checklist before deploying to your Hetzner server.

---

## ✅ 1. Secrets Management (COMPLETED ✓)

- [x] **1Password CLI installed** and authenticated
- [x] **homelab-env vault** created with 24 secrets
- [x] **All secrets verified** - no references, actual values
- [x] **Secrets script tested** - `.kamal/secrets` working

**Verification command:**

```bash
./scripts/verify-secrets.sh
```

---

## 📝 2. Required Configuration Files

### A. Cloudflare API Token File

Create the token file that Traefik will use:

```bash
# Save your Cloudflare API token
echo "YOUR_CLOUDFLARE_API_TOKEN" > config/traefik/cf_api_token.txt

# Secure it
chmod 600 config/traefik/cf_api_token.txt
```

**Get token from:** https://dash.cloudflare.com/profile/api-tokens

**Required permissions:**

- Zone → DNS → Edit
- Zone → Zone → Read
- Zone Resources → Include → Specific zone → `rodneyops.com`

---

### B. Update Configuration Files

#### 1. **config/deploy.yml**

- [x] Server IP: `95.216.176.147` ✓
- [x] Registry: `ghcr.io/rodcyb3dev/homelab` ✓
- [x] Domain: `rodneyops.com` ✓

#### 2. **config/traefik/traefik.yml**

```yaml
# Verify email for Let's Encrypt
certificatesResolvers:
  cloudflare:
    acme:
      email: "edward.bez@DOMAIN.com" # ← Update this if needed
```

#### 3. **docker-compose.yml**

- [x] Domain configured ✓
- [x] Networks defined ✓
- [x] Secrets mapped ✓

---

## 🖥️ 3. Server Preparation

### A. SSH Access

Test SSH connection to your Hetzner server:

```bash
ssh root@95.216.176.147
```

**If not working:**

1. Add your SSH key to the server
2. Or use password authentication temporarily

### B. Server Requirements

SSH into server and verify:

```bash
# Check Docker is installed
docker --version

# If not installed, run:
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Check Docker Compose
docker compose version

# Check available disk space
df -h /

# Should show:
# - Docker 20.10+ or later
# - Docker Compose v2+
# - At least 40GB free space
```

### C. Storage Box Setup (Optional - for Arr Stack)

```bash
# On your server, test Storage Box connectivity
ssh -p 23 u525677@u525677.your-storagebox.de

# If working, mount it:
apt-get install cifs-utils
mkdir -p /mnt/storagebox
```

Update `/etc/fstab`:

```bash
//u525677.your-storagebox.de/backup /mnt/storagebox cifs credentials=/root/.smbcredentials,uid=1000,gid=1000 0 0
```

Create credentials file:

```bash
echo "username=u525677" > /root/.smbcredentials
echo "password=YOUR_STORAGE_BOX_PASSWORD" >> /root/.smbcredentials
chmod 600 /root/.smbcredentials
```

---

## 🔒 4. GitHub Secrets (for CI/CD)

Add these secrets to your GitHub repository:

**Location:** https://github.com/RodCyb3Dev/gandalf-gate-iac/settings/secrets/actions

### Required Secrets:

```yaml
# Server Access
HETZNER_SSH_HOST: 95.216.176.147
HETZNER_SSH_USER: root
HETZNER_SSH_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  YOUR_PRIVATE_SSH_KEY_HERE
  -----END OPENSSH PRIVATE KEY-----
HETZNER_SSH_PORT: 22
# 1Password Integration
OP_SERVICE_ACCOUNT_TOKEN: ops_YOUR_TOKEN_HERE

# Kamal Registry (GitHub Container Registry)
KAMAL_REGISTRY_USERNAME: RodCyb3Dev
KAMAL_REGISTRY_PASSWORD: ghp_YOUR_GITHUB_TOKEN_HERE

# Optional - if using automated backups
STORAGE_BOX_HOST: u525677.your-storagebox.de
STORAGE_BOX_USER: u525677
STORAGE_BOX_PASSWORD: YOUR_STORAGE_BOX_PASSWORD
```

**Get Service Account Token:**

1. Go to: https://1password.com/settings/serviceaccounts
2. Create new service account: "GitHub Actions Homelab"
3. Grant access to `homelab-env` vault (Read-only)
4. Copy token (starts with `ops_`)

---

## 🧪 5. Local Testing (Optional)

Test the infrastructure locally before deploying:

```bash
# Validate docker-compose
make validate

# Test build (without deploying)
docker compose config

# Check for any syntax errors
docker compose -f docker-compose.yml config
```

---

## 🚀 6. Ready to Deploy!

### Option A: Manual Kamal Deployment (Recommended First Time)

```bash
cd /Users/rodneyhammad/Private/Gandalf-gate-docke/homelab

# First-time setup (creates network, folders, etc.)
kamal setup

# Deploy
kamal deploy

# View logs
kamal logs

# Check status
kamal details
```

### Option B: Using Make Commands

```bash
# First-time setup
make kamal-setup

# Deploy
make kamal-deploy

# View logs
make kamal-logs

# Rollback if needed
make kamal-rollback
```

### Option C: GitHub Actions (Automated CI/CD)

Push to main branch:

```bash
git push origin main
```

Monitor deployment:

- https://github.com/RodCyb3Dev/gandalf-gate-iac/actions

---

## 📊 7. Post-Deployment Verification

After deployment, verify services are running:

### A. On Server

```bash
ssh root@95.216.176.147

# Check containers
docker ps

# Should see:
# - traefik
# - authelia
# - crowdsec
# - grafana
# - prometheus
# - loki
# - etc.

# Check networks
docker network ls

# Check volumes
docker volume ls
```

### B. Access Services

Open in browser:

| Service           | URL                           | Credentials               |
| ----------------- | ----------------------------- | ------------------------- |
| Traefik Dashboard | https://traefik.rodneyops.com | Via Authelia SSO          |
| Authelia          | https://auth.rodneyops.com    | Setup 2FA first time      |
| Grafana           | https://grafana.rodneyops.com | rodmin / (from 1Password) |
| Uptime Kuma       | https://status.rodneyops.com  | Via Authelia SSO          |

### C. SSL Certificates

Verify Let's Encrypt certificates:

```bash
ssh root@95.216.176.147
docker exec traefik cat /acme.json

# Should show certificates for your domains
```

### D. Monitoring

Check metrics in Grafana:

- Node Exporter: System metrics
- cAdvisor: Container metrics
- Traefik: HTTP metrics
- CrowdSec: Security events

---

## 🆘 Troubleshooting

### Issue: "Cannot connect to server"

```bash
# Check firewall
ufw status

# Open required ports
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
```

### Issue: "Container keeps restarting"

```bash
# Check logs
kamal logs --service SERVICE_NAME

# Or directly on server
docker logs CONTAINER_NAME
```

### Issue: "SSL certificate not issued"

```bash
# Check Traefik logs
docker logs traefik

# Verify DNS is pointing to server
dig rodneyops.com +short
# Should return: 95.216.176.147

# Check Cloudflare proxy status
# Ensure orange cloud is OFF for ACME challenge
```

### Issue: "Authelia not working"

```bash
# Check Redis connection
docker exec authelia nc -zv redis 6379

# Check PostgreSQL connection
docker exec authelia nc -zv authelia-db 5432

# View Authelia logs
docker logs authelia
```

---

## 📚 Documentation References

- **Main README**: `README.md`
- **Deployment Guide**: `docs/DEPLOYMENT.md`
- **Kamal Guide**: `docs/KAMAL_DEPLOYMENT.md`
- **Security Guide**: `docs/SECURITY.md`
- **Security Checklist**: `docs/SECURITY_CHECKLIST.md`

---

## ✅ Final Checklist

Before running `kamal deploy`:

- [ ] 1Password secrets verified (run `./scripts/verify-secrets.sh`)
- [ ] Cloudflare API token file created (`config/traefik/cf_api_token.txt`)
- [ ] SSH access to server working
- [ ] Docker installed on server
- [ ] DNS records pointing to server IP
- [ ] GitHub secrets configured (for CI/CD)
- [ ] Backup of existing data (if migrating)

---

## 🎯 Deploy Command

When ready, run:

```bash
cd /Users/rodneyhammad/Private/Gandalf-gate-docke/homelab

# Authenticate with 1Password
eval $(op signin)

# Deploy
kamal deploy
```

---

## 📞 Need Help?

- Check logs: `kamal logs`
- SSH to server: `ssh root@95.216.176.147`
- View container status: `docker ps`
- Restart service: `docker restart SERVICE_NAME`
- Full rollback: `kamal rollback`

---

**Good luck with your deployment! 🚀**
