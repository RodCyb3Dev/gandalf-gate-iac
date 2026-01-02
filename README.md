# Secure Homelab Infrastructure

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-required-blue)
![Security](https://img.shields.io/badge/security-hardened-brightgreen)

A production-ready, maximum-security homelab infrastructure with defense-in-depth architecture, zero-trust access controls, and full observability.

## 🎯 Features

### Security

- ✅ **6-Layer Defense-in-Depth** - Cloudflare WAF, Traefik, CrowdSec, Authelia, Fail2ban, Tailscale
- ✅ **Zero-Trust Access Control** - SSO with 2FA for all services
- ✅ **Automated Threat Detection** - CrowdSec IDS/IPS with community blocklists
- ✅ **TLS 1.3 Encryption** - Automatic SSL certificates via Let's Encrypt
- ✅ **Security Scanning** - Automated vulnerability scans via GitHub Actions

### Infrastructure

- ✅ **Docker-based** - Containerized services with resource limits
- ✅ **Network Segmentation** - Isolated networks for public/private/monitoring
- ✅ **High Availability** - Health checks and automatic restarts
- ✅ **Resource Optimized** - Runs on 4GB RAM Hetzner server
- ✅ **Hetzner Storage Box** - Mounted network storage for media

### Observability

- ✅ **Full Metrics Stack** - Prometheus + Grafana + cAdvisor
- ✅ **Centralized Logging** - Loki + Promtail for log aggregation
- ✅ **Real-time Alerts** - Gotify push notifications
- ✅ **Service Monitoring** - Uptime Kuma for availability tracking

### Automation

- ✅ **CI/CD Pipeline** - Automated deployments via GitHub Actions
- ✅ **Automated Backups** - Daily backups to Storage Box
- ✅ **Zero-Downtime Updates** - Rolling deployments
- ✅ **Automated Security Scans** - Weekly vulnerability checks

## 📋 Table of Contents

- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Services](#services)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Security](#security)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## 🏗 Architecture

```
Internet
    ↓
Cloudflare CDN/WAF (Layer 1)
    ↓
Traefik Reverse Proxy (Layer 2)
    ↓
CrowdSec IDS/IPS (Layer 3)
    ↓
Authelia SSO + 2FA (Layer 4)
    ↓
┌────────────────────────────┬─────────────────────────────┐
│   Public Services          │   Private Services          │
│   (HTTPS + Auth)           │   (Tailscale Only)          │
├────────────────────────────┼─────────────────────────────┤
│ • Grafana (Monitoring)     │ • Jellyfin (Media Server)   │
│ • Traefik Dashboard        │ • Sonarr, Radarr (TV/Movies)│
│ • Gotify (Notifications)   │ • Prowlarr (Indexers)       │
│ • Status Page              │ • qBittorrent (Downloads)   │
│                            │ • Portainer (Management)    │
│                            │ • Homarr (Dashboard)        │
└────────────────────────────┴─────────────────────────────┘
         ↓                              ↓
    Monitoring Stack            Hetzner Storage Box
    (Prometheus/Loki)           (1TB Network Storage)
```

### Network Topology

- **Public Network** (`172.20.0.0/24`) - Internet-facing services
- **Private Network** (`172.21.0.0/24`) - Tailscale-only services
- **Monitoring Network** (`172.22.0.0/24`) - Observability stack
- **Security Network** (`172.23.0.0/24`) - Security services

## 🚀 Quick Start

### Prerequisites

- Ubuntu 22.04 LTS server
- Docker 20.10+ and Docker Compose 2.12+
- Domain name with Cloudflare DNS
- Hetzner Storage Box (optional but recommended)
- Tailscale account
- GitHub account (for CI/CD)

### Initial Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/your-username/homelab.git /opt/homelab
   cd /opt/homelab
   ```

2. **Configure environment:**

   ```bash
   # Copy environment template
   cp .env.example .env

   # Edit with your values
   nano .env
   ```

3. **Generate secrets:**

   ```bash
   make generate-secrets
   make setup-acme
   ```

4. **Mount Storage Box (optional):**

   ```bash
   sudo bash scripts/setup-storage-box.sh
   ```

5. **Deploy infrastructure:**

   ```bash
   make up
   ```

6. **Verify deployment:**
   ```bash
   make health
   ```

## 📦 Services

### Public Services (via Traefik + Authelia)

| Service           | URL                     | Purpose                  | Auth               |
| ----------------- | ----------------------- | ------------------------ | ------------------ |
| Traefik Dashboard | `traefik.rodneyops.com` | Reverse proxy monitoring | 2FA + IP whitelist |
| Grafana           | `grafana.rodneyops.com` | Metrics & dashboards     | 2FA                |
| Gotify            | `rodify.rodneyops.com`  | Push notifications       | Password           |
| Uptime Kuma       | `status.rodneyops.com`  | Service status page      | 2FA                |
| Authelia          | `auth.rodneyops.com`    | SSO authentication       | Password + 2FA     |

### Private Services (Tailscale-only)

| Service     | Internal Port | Purpose              |
| ----------- | ------------- | -------------------- |
| Jellyfin    | 8096          | Media streaming      |
| Sonarr      | 8989          | TV show management   |
| Radarr      | 7878          | Movie management     |
| Prowlarr    | 9696          | Indexer management   |
| qBittorrent | 8085          | Torrent client       |
| Lidarr      | 8686          | Music management     |
| Readarr     | 8787          | Book management      |
| Bazarr      | 6767          | Subtitle management  |
| Homarr      | 7575          | Service dashboard    |
| Portainer   | 9000          | Container management |

### Security Services

| Service  | Purpose                       | Port |
| -------- | ----------------------------- | ---- |
| CrowdSec | IDS/IPS & threat intelligence | 6060 |
| Fail2ban | System intrusion prevention   | -    |
| Authelia | SSO & 2FA authentication      | 9091 |

### Monitoring Services

| Service       | Purpose            | Port |
| ------------- | ------------------ | ---- |
| Prometheus    | Metrics collection | 9090 |
| Grafana       | Visualization      | 3000 |
| Loki          | Log aggregation    | 3100 |
| Promtail      | Log shipping       | 9080 |
| Node Exporter | System metrics     | 9100 |
| cAdvisor      | Container metrics  | 8080 |

## ⚙️ Configuration

### Environment Variables

Key environment variables in `.env`:

```bash
# General
TZ=Europe/Helsinki
DOMAIN=rodneyops.com
PUID=1000
PGID=1000

# Hetzner Storage Box
STORAGE_BOX_PASSWORD=your_password

# Cloudflare
CF_API_TOKEN=your_token

# Grafana
GRAFANA_ADMIN_PASSWORD=secure_password

# CrowdSec
CROWDSEC_ENROLL_KEY=your_key
CROWDSEC_BOUNCER_API_KEY=your_api_key

# Tailscale
TAILSCALE_AUTH_KEY=tskey-auth-xxxxx
```

See [`.env.example`](.env.example) for complete list.

### Traefik Configuration

- Static config: [`config/traefik/traefik.yml`](config/traefik/traefik.yml)
- Dynamic config: [`config/traefik/dynamic/`](config/traefik/dynamic/)
- Middlewares: [`config/traefik/dynamic/middlewares.yml`](config/traefik/dynamic/middlewares.yml)

### Authelia Configuration

- Main config: [`config/authelia/configuration.yml`](config/authelia/configuration.yml)
- Users: [`config/authelia/users_database.yml`](config/authelia/users_database.yml)

Generate password hash:

```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourPassword123!'
```

### CrowdSec Configuration

- Acquisitions: [`config/crowdsec/acquis.yaml`](config/crowdsec/acquis.yaml)
- Profiles: [`config/crowdsec/profiles.yaml`](config/crowdsec/profiles.yaml)

Generate bouncer API key:

```bash
docker exec crowdsec cscli bouncers add traefik-bouncer
```

## 🚢 Deployment

### Manual Deployment

```bash
# Start all services
make up

# View logs
make logs

# Check health
make health

# Restart services
make restart
```

### Automated Deployment (GitHub Actions)

1. **Setup GitHub Secrets:**
   - `SSH_HOST` - Hetzner server IP
   - `SSH_USER` - SSH username
   - `SSH_PRIVATE_KEY` - SSH private key
   - `GOTIFY_URL` - Gotify server URL
   - `GOTIFY_TOKEN` - Gotify app token

2. **Deploy:**
   ```bash
   git push origin main
   ```

The CI/CD pipeline will:

- Run security scans
- Validate configuration
- Deploy with zero-downtime
- Run health checks
- Send notifications

## 📊 Monitoring

### Access Dashboards

- **Grafana**: https://grafana.rodneyops.com
- **Prometheus**: http://localhost:9090 (internal)
- **Traefik**: https://traefik.rodneyops.com

### Grafana Dashboards

Pre-configured dashboards:

1. **Infrastructure Overview** - All services, resource usage
2. **Security Dashboard** - CrowdSec stats, Fail2ban, blocked IPs
3. **Traefik Dashboard** - Traffic patterns, response times
4. **Media Stack** - Jellyfin, \*arr services health

### Alerts

Grafana alerts are configured for:

- Service down > 2 minutes
- CPU > 85% for 5 minutes
- Disk > 90%
- Memory > 90%
- SSL certificate expiring < 7 days
- CrowdSec > 50 bans/hour

Alerts are sent to Gotify.

## 🔒 Security

### Security Layers

1. **Cloudflare** - DDoS protection, WAF, rate limiting
2. **Traefik** - TLS 1.3, security headers, rate limiting
3. **CrowdSec** - IDS/IPS, threat intelligence, auto-blocking
4. **Authelia** - SSO, 2FA (TOTP), session management
5. **Fail2ban** - SSH protection, auth failure blocking
6. **Tailscale** - Zero-trust VPN for private services

### Access Control

- **Public services** require Authelia 2FA
- **Admin services** require 2FA + IP whitelist
- **Private services** require Tailscale VPN

### Security Best Practices

✅ All secrets stored in Docker secrets or env files (gitignored)
✅ No services run as root
✅ Resource limits on all containers
✅ Network segmentation between services
✅ Regular security scans (weekly)
✅ Automated backups (daily)
✅ Audit logging to Loki

## 🛠 Maintenance

### Backups

**Automated backups** run daily at 03:00 UTC via GitHub Actions.

Manual backup:

```bash
make backup
```

Restore from backup:

```bash
make restore
```

### Updates

**Automated updates** run daily at 02:00 UTC via GitHub Actions.

Manual update:

```bash
make update
```

### Common Tasks

```bash
# View CrowdSec decisions (bans)
make crowdsec-decisions

# View CrowdSec metrics
make crowdsec-metrics

# Add CrowdSec bouncer
make crowdsec-add-bouncer

# View Authelia users
make authelia-users

# View service status
make ps

# View resource usage
docker stats
```

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
make logs-traefik
make logs-crowdsec
make logs-authelia

# Verify configuration
make validate

# Check health
make health
```

### SSL Certificate Issues

```bash
# Check acme.json permissions
chmod 600 config/traefik/acme.json

# Check Cloudflare API token
cat config/traefik/cf_api_token.txt

# View Traefik logs
make logs-traefik
```

### CrowdSec Not Blocking

```bash
# Check CrowdSec status
docker exec crowdsec cscli metrics

# Check bouncer connection
docker exec crowdsec cscli bouncers list

# Verify log acquisition
docker exec crowdsec cscli metrics
```

### Storage Box Not Mounted

```bash
# Check mount
mountpoint /mnt/hetzner-storage

# Remount
sudo mount -a

# Check credentials
cat /root/.storage-box-credentials
```

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [Security Guide](docs/SECURITY.md)
- [Monitoring Guide](docs/MONITORING.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Traefik](https://traefik.io/) - Modern reverse proxy
- [CrowdSec](https://crowdsec.net/) - Collaborative security
- [Authelia](https://www.authelia.com/) - SSO & 2FA
- [Prometheus](https://prometheus.io/) - Monitoring system
- [Grafana](https://grafana.com/) - Observability platform

## 📞 Support

For issues, questions, or suggestions:

- Open an [Issue](https://github.com/your-username/homelab/issues)
- Email: rodney@kodeflash.dev

---

**Built with ❤️ for maximum security and reliability**
