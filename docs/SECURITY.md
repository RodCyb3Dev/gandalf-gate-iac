# Security Guide

Comprehensive security documentation for the homelab infrastructure.

## Table of Contents

- [Security Architecture](#security-architecture)
- [Authentication & Authorization](#authentication--authorization)
- [Network Security](#network-security)
- [Application Security](#application-security)
- [Monitoring & Incident Response](#monitoring--incident-response)
- [Security Best Practices](#security-best-practices)
- [Compliance](#compliance)

## Security Architecture

### Defense-in-Depth Strategy

The infrastructure implements 6 layers of security:

```
Layer 1: Cloudflare CDN/WAF
    ↓
Layer 2: Traefik Edge Security
    ↓
Layer 3: CrowdSec IDS/IPS
    ↓
Layer 4: Authelia SSO + 2FA
    ↓
Layer 5: Fail2ban System Protection
    ↓
Layer 6: Tailscale Zero-Trust VPN
```

### Layer 1: Cloudflare Protection

**Features:**

- DDoS protection (automatic)
- Web Application Firewall (WAF)
- Bot management
- Rate limiting (5000 req/min globally)
- Geo-blocking (configurable)

**Configuration:**

1. Enable "Under Attack" mode for maximum protection
2. Configure WAF rules: Security → WAF → Managed Rules
3. Enable Bot Fight Mode: Security → Bots
4. Configure rate limiting: Security → Rate Limiting

### Layer 2: Traefik Edge Security

**Features:**

- TLS 1.3 encryption (minimum)
- Security headers (HSTS, CSP, X-Frame-Options)
- Automatic HTTPS redirect
- Rate limiting per service
- IP whitelisting for admin interfaces

**Configuration:**

```yaml
# config/traefik/dynamic/middlewares.yml
security-headers:
  headers:
    stsSeconds: 63072000
    stsIncludeSubdomains: true
    stsPreload: true
    forceSTSHeader: true
    contentSecurityPolicy: "default-src 'self'"
    browserXssFilter: true
    contentTypeNosniff: true
    referrerPolicy: "strict-origin-when-cross-origin"
```

### Layer 3: CrowdSec IDS/IPS

**Features:**

- Real-time threat detection
- Community-sourced threat intelligence
- Automatic IP blocking
- Scenario-based detection
- AppSec virtual patching

**Active Collections:**

- `crowdsecurity/traefik` - Traefik log analysis
- `crowdsecurity/http-cve` - HTTP vulnerability detection
- `crowdsecurity/whitelist-good-actors` - Prevent false positives
- `crowdsecurity/appsec-virtual-patching` - Virtual patches for known vulnerabilities
- `crowdsecurity/appsec-generic-rules` - Generic AppSec rules

**Management Commands:**

```bash
# View active decisions (bans)
docker exec crowdsec cscli decisions list

# View metrics
docker exec crowdsec cscli metrics

# View bouncers
docker exec crowdsec cscli bouncers list

# Unban an IP
docker exec crowdsec cscli decisions delete -i <IP_ADDRESS>

# View scenarios
docker exec crowdsec cscli scenarios list

# Update hub
docker exec crowdsec cscli hub update
docker exec crowdsec cscli hub upgrade
```

### Layer 4: Authelia SSO + 2FA

**Features:**

- Single Sign-On (SSO) for all public services
- Time-based One-Time Password (TOTP) 2FA
- Session management
- Failed login protection (5 attempts = 10 min ban)
- Email notifications for suspicious activity

**User Management:**

```bash
# Generate password hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 \
  --password 'YourPassword123!'

# Add user to config/authelia/users_database.yml
users:
  username:
    displayname: "Display Name"
    password: "$argon2id$..."
    email: "user@domain.com"
    groups:
      - admins  # or users
```

**Access Control Rules:**

```yaml
# config/authelia/configuration.yml
access_control:
  default_policy: "deny"

  rules:
    # Admin services - require 2FA
    - domain:
        - "traefik.rodneyops.com"
        - "portainer.rodneyops.com"
      policy: "two_factor"
      subject:
        - ["group:admins"]

    # Monitoring - require authentication
    - domain:
        - "grafana.rodneyops.com"
      policy: "two_factor"
```

### Layer 5: Fail2ban System Protection

**Features:**

- SSH brute-force protection
- Docker socket protection
- Traefik authentication failure protection
- HTTP DoS protection

**Active Jails:**

```bash
# View all jails
docker exec fail2ban fail2ban-client status

# View specific jail
docker exec fail2ban fail2ban-client status sshd

# Unban IP
docker exec fail2ban fail2ban-client set sshd unbanip <IP_ADDRESS>
```

**Jail Configuration:**

- `sshd`: 3 failures = 1 hour ban
- `traefik-auth`: 5 failures = 1 hour ban
- `traefik-botsearch`: 3 failures = 2 hour ban
- `authelia`: 5 failures = 1 hour ban
- `recidive`: Repeat offenders = 24 hour ban

### Layer 6: Tailscale Zero-Trust VPN

**Features:**

- Zero-trust network access
- End-to-end encrypted
- MagicDNS for service discovery
- ACLs for fine-grained access control
- Subnet routing for private services

**Access Private Services:**

```bash
# From Tailscale-connected device
http://jellyfin.your-tailnet.ts.net
http://sonarr.your-tailnet.ts.net
http://radarr.your-tailnet.ts.net
```

**ACL Configuration:**

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:admins"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["group:users"],
      "dst": ["tag:media:8096,7878,8989"]
    }
  ]
}
```

## Authentication & Authorization

### Password Policy

- **Minimum length**: 12 characters
- **Required**: Uppercase, lowercase, number, special character
- **Hashing**: Argon2id (industry standard)
- **Rotation**: Recommended every 90 days

### Two-Factor Authentication (2FA)

**Setup:**

1. Login to https://auth.rodneyops.com
2. Navigate to "Two-Factor Authentication"
3. Scan QR code with authenticator app
4. Enter verification code
5. Save backup codes securely

**Supported Apps:**

- Google Authenticator
- Authy
- 1Password
- Bitwarden

### Session Management

- **Session duration**: 1 hour active, 5 min inactive
- **Remember me**: 30 days (optional)
- **Session storage**: SQLite (upgradeable to Redis)

## Network Security

### Network Segmentation

| Network    | Subnet        | Purpose                  | Access             |
| ---------- | ------------- | ------------------------ | ------------------ |
| Public     | 172.20.0.0/24 | Internet-facing services | Internet → Traefik |
| Private    | 172.21.0.0/24 | Internal services        | Tailscale only     |
| Monitoring | 172.22.0.0/24 | Observability stack      | Internal only      |
| Security   | 172.23.0.0/24 | Security services        | Internal only      |

### Firewall Rules

```bash
# UFW configuration
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP
ufw allow 443/tcp    # HTTPS
ufw enable
```

### Port Exposure

| Port | Service           | Exposure | Protection              |
| ---- | ----------------- | -------- | ----------------------- |
| 22   | SSH               | Public   | Fail2ban                |
| 80   | HTTP              | Public   | Auto-redirect to 443    |
| 443  | HTTPS             | Public   | All 6 security layers   |
| 8080 | Traefik Dashboard | Internal | Authelia + IP whitelist |

**All other ports** are internal-only or Tailscale-only.

### SSL/TLS Configuration

**Certificates:**

- Provider: Let's Encrypt (via Cloudflare DNS-01)
- Renewal: Automatic (60 days before expiry)
- Storage: `config/traefik/acme.json`

**TLS Configuration:**

- Protocol: TLS 1.3 (minimum)
- Cipher suites: Modern, secure ciphers only
- HSTS: Enabled (2 years, includeSubDomains, preload)

**Verify SSL:**

```bash
# Test TLS configuration
nmap --script ssl-enum-ciphers -p 443 rodneyops.com

# Check certificate
echo | openssl s_client -servername rodneyops.com -connect rodneyops.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Application Security

### Docker Security

**Best Practices Implemented:**

- ✅ No containers run as root
- ✅ Read-only filesystems where possible
- ✅ Resource limits on all containers
- ✅ Security options (`no-new-privileges`)
- ✅ Minimal base images (Alpine when possible)
- ✅ Regular security scans (Trivy)

**Resource Limits:**

```yaml
deploy:
  resources:
    limits:
      memory: 256M
      cpus: "0.5"
```

### Secrets Management

**Docker Secrets:**

- Cloudflare API token
- Authelia secrets (JWT, session, encryption key)
- Other sensitive credentials

**Location:** Never in git repository

- Environment variables: `.env` (gitignored)
- Docker secrets: `config/*/secret*.txt` (gitignored)

**Rotation:**

```bash
# Rotate Authelia secrets
make generate-secrets

# Restart services
docker-compose restart authelia
```

### Vulnerability Scanning

**Automated Scans:**

- Weekly via GitHub Actions
- Tools: Trivy, Docker Bench Security
- Severity threshold: HIGH, CRITICAL

**Manual Scan:**

```bash
make security-scan
```

## Monitoring & Incident Response

### Security Monitoring

**What's Monitored:**

- Failed login attempts (Authelia)
- Banned IPs (CrowdSec, Fail2ban)
- Unusual traffic patterns (Traefik)
- Container security events (Docker)
- System authentication (SSH, sudo)

**Log Aggregation:**

- All logs → Loki
- Retention: 30 days
- Query via Grafana

### Alerts

**Configured Alerts:**

- 🚨 **Critical**: Service down, security breach detected
- ⚠️ **Warning**: High resource usage, certificate expiring
- ℹ️ **Info**: Successful deployment, backup completed

**Alert Destinations:**

- Gotify (push notifications)
- Email (via SMTP)
- Grafana Dashboard

### Incident Response

**In case of security incident:**

1. **Identify** - Check Grafana security dashboard

   ```bash
   docker exec crowdsec cscli alerts list
   docker exec crowdsec cscli decisions list
   ```

2. **Contain** - Block attacker

   ```bash
   docker exec crowdsec cscli decisions add --ip <IP> --duration 24h --type ban
   ```

3. **Investigate** - Check logs

   ```bash
   # View Traefik logs
   make logs-traefik

   # Query Loki
   # Use Grafana → Explore → Loki
   # Query: {service="traefik"} |= "suspicious_pattern"
   ```

4. **Recover** - Restore from backup if needed

   ```bash
   make restore
   ```

5. **Review** - Update security rules
   - Add new CrowdSec scenario
   - Update Fail2ban filters
   - Adjust Authelia access rules

## Security Best Practices

### For Administrators

1. **Use strong, unique passwords** for all services
2. **Enable 2FA** on all accounts
3. **Regularly review** access logs and security alerts
4. **Keep systems updated** (automated via GitHub Actions)
5. **Rotate credentials** every 90 days
6. **Backup regularly** (automated daily)
7. **Test disaster recovery** quarterly

### For Users

1. **Never share credentials**
2. **Use password manager** (1Password, Bitwarden)
3. **Verify SSL certificates** (look for padlock)
4. **Report suspicious activity** immediately
5. **Keep 2FA backup codes** in secure location

### Security Checklist

- [ ] All services behind Authelia 2FA
- [ ] Strong passwords (12+ characters, mixed case, numbers, symbols)
- [ ] 2FA enabled for all admin users
- [ ] Firewall configured (only 22, 80, 443 exposed)
- [ ] CrowdSec connected and active
- [ ] Fail2ban jails active
- [ ] SSL certificates valid and auto-renewing
- [ ] Daily backups configured and tested
- [ ] Security scanning enabled (GitHub Actions)
- [ ] Audit logs enabled and monitored
- [ ] Incident response plan documented

## Compliance

### Security Standards

This infrastructure implements security controls aligned with:

- **NIST Cybersecurity Framework**
- **CIS Docker Benchmark**
- **OWASP Application Security**

### Data Protection

- **Data at rest**: Encrypted via filesystem encryption
- **Data in transit**: TLS 1.3 encryption
- **Backup encryption**: Storage Box with encrypted connection
- **Secret management**: Docker secrets + environment variables

### Audit Logging

All security-relevant events are logged:

- Authentication attempts (successful and failed)
- Authorization decisions
- Configuration changes
- Security alerts and incidents
- System access (SSH, sudo)

Logs are centralized in Loki with 30-day retention.

## Security Contact

**For security issues:**

- Email: rodney@kodeflash.dev
- PGP Key: [Available on request]
- Response time: Within 24 hours

**Responsible Disclosure:**
Please report security vulnerabilities privately before public disclosure.

---

**Last Updated**: January 2026
**Next Review**: April 2026
