# Getting Started - Quick Reference

Welcome to your maximum-security homelab infrastructure! This guide will get you up and running in 30 minutes.

## 🎯 What You Have

A complete, production-ready infrastructure with:

- ✅ **6-layer security** (Cloudflare → Traefik → CrowdSec → Authelia → Fail2ban → Tailscale)
- ✅ **SSO + 2FA** for all services
- ✅ **Full monitoring** (Prometheus + Grafana + Loki)
- ✅ **Automated CI/CD** via GitHub Actions
- ✅ **Daily backups** to Hetzner Storage Box
- ✅ **Zero-downtime deployments**

## 📁 Project Structure

```
homelab/
├── docker-compose.yml          # Main orchestration file
├── .env.example                # Environment template (COPY TO .env)
├── Makefile                    # Operational commands
├── config/                     # All service configurations
│   ├── traefik/               # Reverse proxy config
│   ├── crowdsec/              # IDS/IPS config
│   ├── authelia/              # SSO + 2FA config
│   ├── fail2ban/              # Intrusion prevention
│   ├── prometheus/            # Metrics collection
│   ├── grafana/               # Dashboards
│   └── loki/                  # Log aggregation
├── scripts/                    # Automation scripts
│   ├── backup.sh              # Backup script
│   ├── restore.sh             # Restore script
│   ├── health-check.sh        # Health monitoring
│   └── setup-storage-box.sh   # Storage Box setup
├── .github/workflows/          # CI/CD pipelines
│   ├── deploy.yml             # Deployment automation
│   ├── backup.yml             # Automated backups
│   └── security-scan.yml      # Security scanning
└── docs/                       # Comprehensive documentation
    ├── DEPLOYMENT.md          # Deployment guide
    ├── SECURITY.md            # Security guide
    └── MONITORING.md          # Monitoring guide
```

## 🚀 Quick Setup (30 Minutes)

### Prerequisites Checklist

- [ ] Hetzner server (CX22: 3 vCPU, 4GB RAM)
- [ ] Domain with Cloudflare DNS
- [ ] Cloudflare API token
- [ ] Tailscale account + auth key
- [ ] CrowdSec account + enrollment key

### Step 1: Server Setup (5 minutes)

```bash
# SSH into your server
ssh root@YOUR_SERVER_IP

# Install dependencies
apt update && apt upgrade -y
apt install -y docker.io docker-compose git make

# Clone this repository
git clone YOUR_REPO_URL /opt/homelab
cd /opt/homelab
```

### Step 2: Configuration (10 minutes)

```bash
# 1. Create environment file
cp .env.example .env
nano .env

# 2. Update these critical values:
#    - DOMAIN=your-domain.com
#    - CF_API_TOKEN=your_cloudflare_token
#    - TAILSCALE_AUTH_KEY=your_tailscale_key
#    - CROWDSEC_ENROLL_KEY=your_crowdsec_key
#    - Set strong passwords for all services

# 3. Generate secrets
make generate-secrets

# 4. Create Cloudflare token file
echo "your_cloudflare_token" > config/traefik/cf_api_token.txt
chmod 600 config/traefik/cf_api_token.txt

# 5. Configure Authelia user
# Generate password hash:
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YourPassword123!'

# Edit config/authelia/users_database.yml and add your user with the hash
nano config/authelia/users_database.yml
```

### Step 3: Deploy (10 minutes)

```bash
# Validate configuration
make validate

# Start all services
make up

# Monitor deployment (wait for all services to start)
make logs

# This will take 2-5 minutes as Docker pulls images and starts services
```

### Step 4: Verify (5 minutes)

```bash
# Run health check
make health

# Should see all green checkmarks ✅

# Generate CrowdSec bouncer key
docker exec crowdsec cscli bouncers add traefik-bouncer

# Add the key to .env as CROWDSEC_BOUNCER_API_KEY
# Then restart bouncer:
docker-compose restart crowdsec-bouncer-traefik
```

### Step 5: Access Services

1. **Setup 2FA:**
   - Visit `https://auth.YOUR_DOMAIN.com`
   - Login with your credentials
   - Scan QR code with Google Authenticator
   - Save backup codes!

2. **Access Grafana:**
   - Visit `https://grafana.YOUR_DOMAIN.com`
   - Complete 2FA
   - Explore pre-configured dashboards

3. **Configure Tailscale:**
   - Visit `https://login.tailscale.com/admin/machines`
   - Approve "homelab-gateway"
   - Access private services via Tailscale

## 🎛️ Common Commands

```bash
# Service Management
make up           # Start all services
make down         # Stop all services
make restart      # Restart all services
make ps           # Show running services
make logs         # View all logs
make health       # Health check

# Monitoring
make logs-traefik      # Traefik logs
make logs-crowdsec     # CrowdSec logs
make logs-authelia     # Authelia logs

# Security
make crowdsec-decisions    # View banned IPs
make crowdsec-metrics      # CrowdSec statistics

# Maintenance
make backup       # Manual backup
make restore      # Restore from backup
make update       # Update all images
make clean        # Cleanup old containers

# Validation
make validate     # Validate configuration
make security-scan # Run security scan
```

## 🔐 Services Overview

### Public Services (Require 2FA)

- **Grafana**: `https://grafana.YOUR_DOMAIN.com` - Monitoring dashboards
- **Traefik**: `https://traefik.YOUR_DOMAIN.com` - Reverse proxy dashboard
- **Gotify**: `https://rodify.YOUR_DOMAIN.com` - Push notifications
- **Status**: `https://status.YOUR_DOMAIN.com` - Service status page

### Private Services (Tailscale-only)

- **Jellyfin**: Port 8096 - Media streaming
- **Sonarr**: Port 8989 - TV shows
- **Radarr**: Port 7878 - Movies
- **Prowlarr**: Port 9696 - Indexers
- **qBittorrent**: Port 8085 - Torrents
- **Portainer**: Port 9000 - Container management
- **Homarr**: Port 7575 - Dashboard

## 📊 Monitoring

### Grafana Dashboards

1. **Infrastructure Overview** - All services, resources
2. **Security Dashboard** - CrowdSec, Fail2ban stats
3. **Traefik Dashboard** - Traffic patterns
4. **Media Stack** - Jellyfin, \*arr services

### Key Metrics

- **System**: CPU, Memory, Disk usage
- **Security**: Banned IPs, blocked requests
- **Services**: Uptime, response times
- **Network**: Traffic volume, latency

### Alerts (via Gotify)

- Service down > 2 minutes
- CPU > 85% for 5 minutes
- Disk > 90%
- SSL certificate expiring < 7 days
- CrowdSec > 50 bans/hour (attack detected)

## 🔧 Troubleshooting

### Services Won't Start

```bash
# Check specific service logs
docker-compose logs SERVICE_NAME

# Common fixes:
make validate          # Check configuration
sudo chmod -R 1000:1000 config/  # Fix permissions
make down && make up   # Full restart
```

### Can't Access Services

```bash
# Check DNS
nslookup YOUR_DOMAIN.com

# Check SSL certificates
docker-compose logs traefik | grep -i certificate

# Check Traefik dashboard
curl http://localhost:8080/api/http/routers
```

### CrowdSec Not Blocking

```bash
# Check CrowdSec connection
docker exec crowdsec cscli metrics

# Check bouncer
docker exec crowdsec cscli bouncers list

# Should show "traefik-bouncer" as active
```

## 🚨 Emergency Procedures

### Restore from Backup

```bash
cd /opt/homelab
make restore
# Follow prompts to select backup
```

### Block Malicious IP

```bash
docker exec crowdsec cscli decisions add \
  --ip 1.2.3.4 \
  --duration 24h \
  --type ban \
  --reason "Manual ban"
```

### Reset Admin Password

```bash
# Generate new hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'NewPassword123!'

# Update config/authelia/users_database.yml
# Restart Authelia
docker-compose restart authelia
```

## 📚 Next Steps

1. **Review Security Guide**: See `docs/SECURITY.md`
2. **Setup GitHub Actions**: See `docs/DEPLOYMENT.md#github-actions-setup`
3. **Configure Jellyfin**: Access via Tailscale and add media
4. **Customize Grafana**: Add your own dashboards
5. **Test Backups**: Run `make backup` and verify
6. **Review Logs**: Familiarize yourself with Grafana Loki

## 🆘 Need Help?

- **Documentation**: Check `docs/` folder
- **Logs**: Use `make logs` or Grafana
- **Health Check**: Run `make health`
- **Support**: rodney@kodeflash.dev

## 🎉 You're All Set!

Your infrastructure is now:

- ✅ Secured with 6 layers of protection
- ✅ Monitored with full observability
- ✅ Backed up daily automatically
- ✅ Ready for automated deployments

**Recommended First Actions:**

1. Setup 2FA for your user
2. Access Grafana and explore dashboards
3. Test CrowdSec by simulating bad requests
4. Setup GitHub Actions for automated deployments
5. Configure your media services (Jellyfin, Sonarr, Radarr)

---

**Welcome to your secure homelab! 🚀**
