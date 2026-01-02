# Security Checklist

Complete security checklist before going to production.

## Pre-Deployment Security Checklist

### 🔐 Secrets Management

- [ ] All secrets stored in 1Password or encrypted
- [ ] `.env` file gitignored (never committed)
- [ ] No hardcoded passwords in any files
- [ ] SSH keys have strong passphrases
- [ ] API tokens rotated from defaults
- [ ] ACME certificate file has correct permissions (600)
- [ ] Secret files not accessible via web

### 🔒 Authentication

- [ ] Strong admin passwords (16+ characters)
- [ ] 2FA enabled for all admin users
- [ ] Authelia configured with TOTP
- [ ] Default passwords changed for all services
- [ ] Guest/demo accounts disabled
- [ ] Password policy enforced (min 12 chars)

### 🌐 Network Security

- [ ] Firewall configured (only ports 22, 80, 443 open)
- [ ] SSH key-based authentication only
- [ ] SSH root login disabled (or restricted)
- [ ] Private services only via Tailscale
- [ ] Network segmentation configured
- [ ] No services binding to 0.0.0.0 unnecessarily

### 🛡️ Service Configuration

- [ ] Traefik dashboard behind Authelia + IP whitelist
- [ ] CrowdSec enrolled and active
- [ ] Fail2ban jails configured and active
- [ ] Security headers enabled (HSTS, CSP, etc.)
- [ ] TLS 1.3 minimum enforced
- [ ] Rate limiting configured
- [ ] No containers running as root

### 📊 Monitoring & Alerting

- [ ] Grafana alerts configured
- [ ] Gotify notifications working
- [ ] Log aggregation to Loki enabled
- [ ] Failed login attempts monitored
- [ ] Resource usage alerts set
- [ ] Certificate expiry alerts enabled
- [ ] Uptime monitoring configured

### 💾 Backup & Recovery

- [ ] Automated daily backups configured
- [ ] Backup tested (can restore)
- [ ] Backup stored offsite (Storage Box)
- [ ] Backup encryption verified
- [ ] Recovery procedure documented
- [ ] Backup integrity checks automated

### 🔍 Vulnerability Management

- [ ] Docker images from trusted sources only
- [ ] Automated security scans enabled (Trivy)
- [ ] Regular update schedule defined
- [ ] CVE monitoring configured
- [ ] Security mailing lists subscribed

### 📝 Documentation & Compliance

- [ ] Security documentation complete
- [ ] Incident response plan documented
- [ ] Access control policy documented
- [ ] Admin contacts documented
- [ ] Change log maintained

### 🚀 Deployment Security

- [ ] CI/CD pipeline uses secrets from vault
- [ ] Deployment requires approval
- [ ] Rollback procedure tested
- [ ] Health checks automated
- [ ] Zero-downtime deployment verified

## Post-Deployment Verification

### Initial Tests

```bash
# 1. Verify all services running
make health

# 2. Check CrowdSec status
docker exec crowdsec cscli metrics

# 3. Verify Fail2ban jails
docker exec fail2ban fail2ban-client status

# 4. Test Authelia 2FA
# Visit https://auth.YOUR_DOMAIN.com and test login

# 5. Verify SSL certificates
echo | openssl s_client -servername YOUR_DOMAIN -connect YOUR_DOMAIN:443 2>/dev/null | openssl x509 -noout -dates

# 6. Test backup
make backup

# 7. Test rollback
make restore
```

### Security Tests

```bash
# 1. Test rate limiting
for i in {1..200}; do curl https://YOUR_DOMAIN.com; done

# 2. Test CrowdSec blocking
# From external IP, make malicious requests
for i in {1..100}; do curl https://YOUR_DOMAIN.com/admin; done

# 3. Verify Fail2ban SSH protection
# Try SSH with wrong password 5 times

# 4. Test Authelia login failure protection
# Try wrong password 5 times on auth page

# 5. Check exposed ports
nmap -p- YOUR_SERVER_IP

# 6. SSL configuration test
nmap --script ssl-enum-ciphers -p 443 YOUR_DOMAIN.com
```

### Monitoring Verification

```bash
# 1. Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# 2. Check Grafana health
curl http://localhost:3000/api/health

# 3. Check Loki
curl http://localhost:3100/ready

# 4. Test Gotify notifications
curl -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
  -F "title=Test" \
  -F "message=Security checklist verification"
```

## Ongoing Security Tasks

### Daily

- [ ] Review CrowdSec alerts
- [ ] Check service health
- [ ] Verify backups completed

### Weekly

- [ ] Review access logs
- [ ] Check for failed login attempts
- [ ] Review Grafana security dashboard
- [ ] Update Docker images

### Monthly

- [ ] Rotate credentials
- [ ] Review access control rules
- [ ] Test disaster recovery
- [ ] Review security incidents
- [ ] Update documentation

### Quarterly

- [ ] Full security audit
- [ ] Penetration testing
- [ ] Review and update firewall rules
- [ ] Update incident response plan
- [ ] Team security training

## Security Incident Response

### Detection

1. Monitor Grafana security dashboard
2. Check CrowdSec alerts
3. Review Loki logs
4. Check Gotify notifications

### Response

1. **Identify** - Determine nature and scope
2. **Contain** - Block attacker (CrowdSec/Fail2ban)
3. **Investigate** - Review logs in Grafana/Loki
4. **Recover** - Restore from backup if needed
5. **Document** - Record incident details
6. **Improve** - Update security rules

### Emergency Contacts

- Admin: rodney@kodeflash.dev
- Hetzner Support: https://www.hetzner.com/support
- Cloudflare Support: https://www.cloudflare.com/support

## Compliance Checklist

### GDPR (if applicable)

- [ ] Data encryption at rest and in transit
- [ ] Data backup and recovery procedures
- [ ] Access logging and audit trail
- [ ] Data retention policy
- [ ] Privacy policy documented

### Security Best Practices

- [ ] Principle of least privilege
- [ ] Defense in depth
- [ ] Zero trust network access
- [ ] Automated security updates
- [ ] Regular security audits

## Tools for Security Testing

```bash
# Port scanning
nmap -sV -p- YOUR_SERVER_IP

# SSL testing
testssl YOUR_DOMAIN.com

# Web application testing
nikto -h https://YOUR_DOMAIN.com

# Docker security
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity HIGH,CRITICAL traefik:v3.3.6

# Docker bench security
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security
```

## Security Score

Track your security posture:

- [ ] All critical items: 100%
- [ ] All high items: 90%+
- [ ] All medium items: 80%+
- [ ] Regular monitoring: Yes
- [ ] Incident response ready: Yes

**Target Score**: 95%+ compliance

## Questions?

- Review [SECURITY.md](SECURITY.md) for detailed security guide
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Contact: rodney@kodeflash.dev

---

**Last Updated**: January 2026
**Next Review**: April 2026
