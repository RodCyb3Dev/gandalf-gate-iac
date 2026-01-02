# Deployment Guide

Complete guide for deploying the secure homelab infrastructure to Hetzner server.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Pre-Deployment](#pre-deployment)
- [Initial Deployment](#initial-deployment)
- [Post-Deployment](#post-deployment)
- [GitHub Actions Setup](#github-actions-setup)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Server Requirements

- **Provider**: Hetzner Cloud
- **Plan**: CX22 or higher (3 vCPU, 4GB RAM, 80GB disk)
- **OS**: Ubuntu 22.04 LTS
- **Network**: Public IP address
- **Storage**: Hetzner Storage Box (optional, 75GB minimum)

### Domain & DNS

1. **Domain** registered with any provider
2. **Cloudflare account** with domain added
3. **DNS** configured to point to your server:
   ```
   A     @              <YOUR_SERVER_IP>
   A     *              <YOUR_SERVER_IP>
   CNAME traefik        rodneyops.com
   CNAME grafana        rodneyops.com
   CNAME auth           rodneyops.com
   CNAME rodify         rodneyops.com
   CNAME status         rodneyops.com
   ```

### Required Accounts

- [x] Cloudflare account (for DNS and SSL)
- [x] Tailscale account (for private network)
- [x] CrowdSec account (for threat intelligence)
- [x] GitHub account (for CI/CD)
- [x] ProtonMail or SMTP service (for email notifications)

### Local Requirements

- SSH client
- Git
- Text editor

## Pre-Deployment

### Step 1: Server Preparation

1. **SSH into your Hetzner server:**

   ```bash
   ssh root@<YOUR_SERVER_IP>
   ```

2. **Update system:**

   ```bash
   apt update && apt upgrade -y
   ```

3. **Install required packages:**

   ```bash
   apt install -y \
     docker.io \
     docker-compose \
     cifs-utils \
     git \
     make \
     curl \
     wget \
     jq \
     htop
   ```

4. **Enable Docker:**

   ```bash
   systemctl enable docker
   systemctl start docker
   ```

5. **Configure firewall:**
   ```bash
   ufw allow 22/tcp    # SSH
   ufw allow 80/tcp    # HTTP
   ufw allow 443/tcp   # HTTPS
   ufw enable
   ```

### Step 2: Cloudflare Setup

1. **Create API Token:**
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Click "Create Token"
   - Use "Edit zone DNS" template
   - Select your domain
   - Copy the token

2. **Enable Cloudflare Proxy:**
   - In Cloudflare DNS settings
   - Enable orange cloud for public records
   - This provides DDoS protection

### Step 3: Tailscale Setup

1. **Create auth key:**
   - Go to https://login.tailscale.com/admin/settings/keys
   - Generate an auth key
   - Enable "Reusable" and "Ephemeral"
   - Set expiration as needed

2. **Note your tailnet name:**
   - Example: `your-name-tailnet.ts.net`

### Step 4: CrowdSec Enrollment

1. **Create account:**
   - Go to https://app.crowdsec.net/
   - Sign up for free account

2. **Get enrollment key:**
   - In Console, go to "Engines"
   - Click "Add Security Engine"
   - Copy enrollment key

## Initial Deployment

### Step 1: Clone Repository

```bash
# Create deployment directory
mkdir -p /opt/homelab
cd /opt/homelab

# Clone repository
git clone https://github.com/your-username/homelab.git .

# Or if private repo:
git clone git@github.com:your-username/homelab.git .
```

### Step 2: Configuration

1. **Create environment file:**

   ```bash
   cp .env.example .env
   nano .env
   ```

2. **Configure critical values:**

   ```bash
   # Domain
   DOMAIN=rodneyops.com

   # Timezone
   TZ=Europe/Helsinki

   # User/Group IDs (run 'id' to find yours)
   PUID=1000
   PGID=1000

   # Cloudflare
   CF_API_TOKEN=your_cloudflare_token

   # Tailscale
   TAILSCALE_AUTH_KEY=tskey-auth-xxxxx
   TAILSCALE_DOMAIN=your-tailnet.ts.net

   # CrowdSec
   CROWDSEC_ENROLL_KEY=your_enrollment_key

   # Admin Passwords (use strong passwords!)
   GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)
   GOTIFY_ADMIN_PASSWORD=$(openssl rand -base64 32)

   # SMTP (for Authelia notifications)
   SMTP_HOST=smtp.protonmail.ch
   SMTP_PORT=587
   SMTP_USERNAME=your_email@domain.com
   SMTP_PASSWORD=your_smtp_password

   # VPN (for *arr services)
   VPN_PROVIDER=protonvpn
   VPN_PRIVATE_KEY=your_wireguard_key
   VPN_ADDRESSES=10.2.0.2/32
   VPN_COUNTRIES=Netherlands

   # Hetzner Storage Box (if using)
   STORAGE_BOX_PASSWORD=your_storage_box_password
   ```

3. **Generate secrets:**

   ```bash
   make generate-secrets
   ```

   This creates:
   - `config/authelia/jwt_secret.txt`
   - `config/authelia/session_secret.txt`
   - `config/authelia/storage_encryption_key.txt`

4. **Setup ACME certificate file:**

   ```bash
   make setup-acme
   ```

5. **Create Cloudflare token file:**
   ```bash
   echo "your_cloudflare_api_token" > config/traefik/cf_api_token.txt
   chmod 600 config/traefik/cf_api_token.txt
   ```

### Step 3: Configure Authelia Users

1. **Edit users database:**

   ```bash
   nano config/authelia/users_database.yml
   ```

2. **Generate password hash:**

   ```bash
   docker run --rm authelia/authelia:latest \
     authelia crypto hash generate argon2 \
     --password 'YourSecurePassword123!'
   ```

3. **Update user entry:**
   ```yaml
   users:
     rodney:
       displayname: "Rodney Hammad"
       password: "$argon2id$v=19$m=65536,t=3,p=4$HASH_FROM_ABOVE"
       email: "rodney@kodeflash.dev"
       groups:
         - admins
         - users
   ```

### Step 4: Mount Storage Box (Optional)

If using Hetzner Storage Box:

```bash
sudo bash scripts/setup-storage-box.sh
```

Follow the prompts to:

1. Choose mount method (CIFS or SSHFS)
2. Enter credentials
3. Verify mount
4. Create directory structure

### Step 5: Deploy Infrastructure

1. **Validate configuration:**

   ```bash
   make validate
   ```

2. **Start services:**

   ```bash
   make up
   ```

   This will:
   - Pull all Docker images
   - Create networks
   - Start all containers
   - Setup SSL certificates

3. **Monitor deployment:**

   ```bash
   make logs
   ```

   Wait for all services to start (2-5 minutes).

### Step 6: Initial Configuration

1. **Generate CrowdSec bouncer key:**

   ```bash
   docker exec crowdsec cscli bouncers add traefik-bouncer
   ```

   Copy the API key and add to `.env`:

   ```bash
   CROWDSEC_BOUNCER_API_KEY=the_generated_key
   ```

2. **Restart to apply bouncer key:**

   ```bash
   docker-compose restart crowdsec-bouncer-traefik
   ```

3. **Verify CrowdSec connection:**
   ```bash
   docker exec crowdsec cscli bouncers list
   ```

## Post-Deployment

### Step 1: Access Services

1. **Setup 2FA in Authelia:**
   - Visit https://auth.rodneyops.com
   - Login with your credentials
   - Setup TOTP (use Google Authenticator or Authy)
   - Save backup codes

2. **Access Grafana:**
   - Visit https://grafana.rodneyops.com
   - Complete Authelia 2FA
   - Login with admin credentials from `.env`
   - Change default password

3. **Access Traefik Dashboard:**
   - Visit https://traefik.rodneyops.com
   - Complete Authelia 2FA
   - Verify all services are detected

4. **Setup Gotify:**
   - Visit https://rodify.rodneyops.com
   - Login with credentials from `.env`
   - Create an application
   - Copy token for alerts

### Step 2: Configure Tailscale Access

1. **Approve machine in Tailscale:**
   - Go to https://login.tailscale.com/admin/machines
   - Approve "homelab-gateway"
   - Enable subnet routes

2. **Test private service access:**

   ```bash
   # From Tailscale-connected device
   curl http://100.x.x.x:8096  # Jellyfin
   ```

3. **Configure Jellyfin:**
   - Access via Tailscale IP
   - Complete initial setup
   - Add media libraries (pointing to `/media`)

### Step 3: Health Check

```bash
make health
```

Verify all checks pass:

- ✅ All containers running
- ✅ All ports open
- ✅ All endpoints responding
- ✅ Resource usage normal
- ✅ SSL certificates valid
- ✅ Storage Box mounted

### Step 4: Test Security

1. **Test Authelia 2FA:**
   - Try accessing service without auth → Should redirect to Authelia
   - Login with wrong password → Should be blocked after 5 attempts
   - Login with correct password → Should require 2FA

2. **Test CrowdSec:**

   ```bash
   # Simulate bad requests (from external machine)
   for i in {1..100}; do curl https://rodneyops.com/admin; done

   # Check if IP was banned
   docker exec crowdsec cscli decisions list
   ```

3. **Test Fail2ban:**

   ```bash
   # View active jails
   docker exec fail2ban fail2ban-client status

   # View SSH jail
   docker exec fail2ban fail2ban-client status sshd
   ```

## GitHub Actions Setup

### Step 1: Generate SSH Key

```bash
# On your local machine
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github-actions

# Copy public key to server
ssh-copy-id -i ~/.ssh/github-actions.pub root@<YOUR_SERVER_IP>
```

### Step 2: Configure GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:

- `SSH_HOST`: Your Hetzner server IP
- `SSH_USER`: `root`
- `SSH_PORT`: `22`
- `SSH_PRIVATE_KEY`: Contents of `~/.ssh/github-actions`
- `GOTIFY_URL`: `https://rodify.rodneyops.com`
- `GOTIFY_TOKEN`: Token from Gotify app

### Step 3: Initialize Git Repository on Server

```bash
cd /opt/homelab
git init
git remote add origin https://github.com/your-username/homelab.git
git branch -M main
git pull origin main
```

### Step 4: Test Deployment

```bash
# Make a small change
echo "# Test" >> README.md
git add .
git commit -m "Test automated deployment"
git push origin main
```

Check GitHub Actions tab for deployment status.

## Troubleshooting

### Services Won't Start

```bash
# Check specific service
docker-compose logs service_name

# Common issues:
# 1. Port already in use
sudo netstat -tulpn | grep :80

# 2. Permission issues
sudo chown -R 1000:1000 config/

# 3. Invalid configuration
make validate
```

### SSL Certificates Not Working

```bash
# Check acme.json permissions
chmod 600 config/traefik/acme.json

# Check Cloudflare token
docker-compose logs traefik | grep -i cloudflare

# Manual certificate request
docker-compose restart traefik
```

### CrowdSec Not Starting

```bash
# Check logs
docker-compose logs crowdsec

# Reset CrowdSec
docker-compose down
sudo rm -rf config/crowdsec/db/*
docker-compose up -d crowdsec
```

### Storage Box Mount Failed

```bash
# Check credentials
cat /root/.storage-box-credentials

# Test connectivity
ping u525677.your-storagebox.de

# Remount
sudo umount /mnt/hetzner-storage
sudo mount -a
```

### GitHub Actions Failing

```bash
# Check SSH connection
ssh -i ~/.ssh/github-actions root@<YOUR_SERVER_IP>

# Verify secrets are set
# Go to GitHub → Settings → Secrets

# Check workflow logs
# Go to GitHub → Actions → Select failed workflow
```

## Next Steps

- [Security Hardening](SECURITY.md)
- [Monitoring Setup](MONITORING.md)
- [Maintenance Tasks](../README.md#maintenance)

---

For additional help, open an issue or contact rodney@kodeflash.dev
