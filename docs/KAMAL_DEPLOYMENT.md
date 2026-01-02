# Kamal Deployment Guide

Modern, zero-downtime deployments using Kamal (formerly MRSK).

## What is Kamal?

Kamal deploys web apps anywhere from bare metal to cloud VMs using Docker with zero downtime. It uses the dynamic reverse-proxy Traefik to hold requests while containers are stopped and new ones are started.

### Benefits

- ✅ **Zero-downtime deployments** - Rolling updates with health checks
- ✅ **No file transfers** - Only Docker images are deployed
- ✅ **GitOps workflow** - Deploy from CI/CD or locally
- ✅ **Rollback support** - Instant rollback to previous versions
- ✅ **Environment parity** - Same deployment method for staging/production
- ✅ **SSH-based** - No agents or complex setup required

## Prerequisites

1. **Ruby 3.0+** installed locally

   ```bash
   ruby --version
   ```

2. **Kamal installed**

   ```bash
   gem install kamal
   # or
   make kamal-setup
   ```

3. **Docker registry access** (GitHub Container Registry)

   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

4. **SSH access** to your Hetzner server
   ```bash
   ssh-copy-id root@YOUR_SERVER_IP
   ```

## Configuration

### 1. Update deploy.yml

Edit `config/deploy.yml`:

```yaml
service: homelab
image: ghcr.io/YOUR_USERNAME/homelab

servers:
  web:
    hosts:
      - YOUR_HETZNER_IP
```

### 2. Setup Environment Variables

#### Option A: Using 1Password (Recommended)

```bash
# Setup 1Password integration
make setup-1password

# Deploy with secrets injected
make kamal-deploy
```

#### Option B: Using .env file

```bash
# Create .env from template
cp .env.example .env

# Edit with your values
nano .env

# Deploy
kamal deploy
```

### 3. Configure GitHub Container Registry

1. Create GitHub Personal Access Token:
   - Go to GitHub → Settings → Developer Settings → Personal Access Tokens
   - Select "Tokens (classic)"
   - Generate new token with `write:packages` scope

2. Add to 1Password or .env:
   ```bash
   KAMAL_REGISTRY_USERNAME=your-github-username
   KAMAL_REGISTRY_PASSWORD=ghp_xxxxxxxxxxxx
   ```

## Deployment

### First-Time Setup

```bash
# 1. Build and push initial image
docker build -t ghcr.io/YOUR_USERNAME/homelab:latest .
docker push ghcr.io/YOUR_USERNAME/homelab:latest

# 2. Initialize Kamal on server
kamal setup

# 3. Deploy
kamal deploy
```

### Regular Deployments

```bash
# Deploy latest changes
make kamal-deploy

# Or manually
kamal deploy
```

### Deployment Flow

```
1. Build Docker image locally or in CI
2. Push image to GitHub Container Registry
3. Kamal connects to server via SSH
4. Downloads new image
5. Starts new containers
6. Health checks pass
7. Switches Traefik to new containers
8. Stops old containers
9. Cleanup
```

## Common Commands

```bash
# Deploy
make kamal-deploy              # Full deployment
make kamal-redeploy           # Redeploy current version

# Rollback
make kamal-rollback           # Rollback to previous version

# Monitoring
make kamal-logs               # View logs
make kamal-details            # Show deployment details

# Maintenance
make kamal-console            # SSH into container
kamal app exec "docker ps"    # Run command on server

# Accessories (databases, etc.)
kamal accessory boot db       # Start database
kamal accessory reboot db     # Restart database
```

## GitHub Actions Integration

The workflow automatically:

1. **Builds** Docker image on every push to `main`
2. **Pushes** to GitHub Container Registry
3. **Deploys** using Kamal
4. **Verifies** deployment health
5. **Notifies** via Gotify

### Required GitHub Secrets

Add these in GitHub → Settings → Secrets:

- `SSH_PRIVATE_KEY` - SSH private key for server access
- `STORAGE_BOX_PASSWORD`
- `CF_API_TOKEN`
- `TAILSCALE_AUTH_KEY`
- `CROWDSEC_ENROLL_KEY`
- `CROWDSEC_BOUNCER_API_KEY`
- `AUTHELIA_JWT_SECRET`
- `AUTHELIA_SESSION_SECRET`
- `AUTHELIA_STORAGE_ENCRYPTION_KEY`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `GRAFANA_ADMIN_PASSWORD`
- `GOTIFY_ADMIN_PASSWORD`
- `VPN_PRIVATE_KEY`
- `GOTIFY_URL`
- `GOTIFY_TOKEN`

## Rollback

### Automatic Rollback

If deployment fails, Kamal automatically rolls back:

```bash
# Health check fails
# → Kamal detects failure
# → Switches back to old containers
# → Deployment marked as failed
```

### Manual Rollback

```bash
# Rollback to previous version
make kamal-rollback

# Or specify version
kamal rollback VERSION_NUMBER
```

## Troubleshooting

### Deployment Fails

```bash
# Check logs
kamal app logs

# Check server status
kamal details

# SSH to server
kamal app exec -i bash
```

### Health Check Fails

```bash
# Test health endpoint locally
curl http://localhost:8080/ping

# Check Traefik logs
kamal app exec "docker logs traefik"
```

### Image Pull Fails

```bash
# Verify registry credentials
docker login ghcr.io

# Check image exists
docker pull ghcr.io/YOUR_USERNAME/homelab:latest
```

### SSH Connection Issues

```bash
# Test SSH connection
ssh root@YOUR_SERVER_IP

# Verify SSH key
kamal app exec "echo 'SSH works'"
```

## Advanced Usage

### Custom Build Context

```yaml
# config/deploy.yml
builder:
  context: .
  dockerfile: Dockerfile.production
  args:
    RAILS_ENV: production
```

### Multiple Servers

```yaml
servers:
  web:
    hosts:
      - 1.2.3.4
      - 5.6.7.8
    options:
      "add-host": "host.docker.internal:host-gateway"
```

### Custom Healthchecks

```yaml
healthcheck:
  path: /health
  port: 8080
  max_attempts: 7
  interval: 10s
  timeout: 5s
  visible_only: false
```

### Pre/Post Deploy Hooks

```bash
# .kamal/hooks/pre-deploy
#!/bin/bash
echo "Running pre-deployment tasks..."
make backup

# .kamal/hooks/post-deploy
#!/bin/bash
echo "Running post-deployment tasks..."
curl -X POST https://status.example.com/heartbeat
```

## Comparison: Kamal vs Traditional Deployment

| Feature          | Traditional (SSH + scp) | Kamal              |
| ---------------- | ----------------------- | ------------------ |
| Downtime         | Minutes                 | Zero               |
| Rollback         | Manual, slow            | Instant            |
| File transfer    | All files via scp       | Docker images only |
| Consistency      | Varies                  | Always same        |
| Health checks    | Manual                  | Automatic          |
| Multiple servers | Complex                 | Built-in           |

## Cost Savings

With Kamal:

- **No downtime** = No lost users
- **Faster deployments** = More frequent updates
- **Easier rollbacks** = Less risk
- **No special tooling** = No additional costs

## Best Practices

1. **Always test locally first**

   ```bash
   docker build -t homelab:test .
   docker run --rm homelab:test
   ```

2. **Use semantic versioning**

   ```bash
   kamal deploy --version=v1.2.3
   ```

3. **Monitor deployments**

   ```bash
   kamal app logs -f
   ```

4. **Keep images small**
   - Use multi-stage builds
   - Use Alpine base images
   - Clean up in same layer

5. **Always backup before deployment**
   ```bash
   make backup
   ```

## Resources

- [Kamal Documentation](https://kamal-deploy.org/)
- [Kamal GitHub](https://github.com/basecamp/kamal)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

**Questions?** Check the [troubleshooting section](#troubleshooting) or open an issue.
