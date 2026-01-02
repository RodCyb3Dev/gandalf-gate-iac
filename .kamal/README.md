# Kamal Deployment Configuration

This directory contains Kamal-specific files for zero-downtime deployments.

## Files

### `secrets`

Executable script that outputs environment variables for deployment.

**How it works:**

1. First tries to fetch secrets from 1Password CLI (vault: `homelab-env`)
2. Falls back to `.env` file if 1Password is not available
3. Outputs secrets in `KEY=VALUE` format for Kamal to inject

**Usage:**

```bash
# Test secrets locally (won't expose actual values)
./.kamal/secrets >/dev/null && echo "✅ Secrets OK" || echo "❌ Secrets failed"

# View secrets (be careful!)
./.kamal/secrets

# Set custom vault name
KAMAL_SECRETS_VAULT="my-vault" ./.kamal/secrets

# Use specific .env file
KAMAL_SECRETS_ENV_FILE=".env.production" ./.kamal/secrets
```

**Environment Variables:**

- `KAMAL_SECRETS_VAULT` - 1Password vault name (default: `homelab-env`)
- `KAMAL_SECRETS_ENV_FILE` - Fallback .env file (default: `.env`)

### `hooks/pre-deploy`

Runs before deployment to check system health:

- ✅ Traefik status check
- ✅ Disk space validation (fails if >90%)

### `hooks/post-deploy`

Runs after deployment to verify:

- ✅ Container health checks
- ✅ Service accessibility
- ✅ Log health checks

## Setup

### Option 1: 1Password (Recommended)

```bash
# Install 1Password CLI
brew install --cask 1password-cli

# Authenticate
op signin

# Create vault
op vault create homelab-env

# Add secrets
op item create --vault homelab-env --title DOMAIN --password "rodneyops.com"
op item create --vault homelab-env --title CF_API_KEY --password "your-api-key"
# ... add all other secrets
```

### Option 2: .env File (Fallback)

Create a `.env` file in the homelab directory:

```bash
# Copy from example
cp .env.example .env

# Edit with your values
nano .env
```

**⚠️ Warning:** Never commit `.env` to Git! It's in `.gitignore`.

## Kamal Commands

```bash
# First-time setup
kamal setup

# Deploy
kamal deploy

# Deploy specific service
kamal deploy --service web

# View logs
kamal logs

# Rollback
kamal rollback

# SSH into container
kamal app exec -i bash

# View deployment details
kamal details

# Remove deployment
kamal remove
```

## CI/CD Integration

GitHub Actions workflow: `.github/workflows/deploy-kamal.yml`

**Required GitHub Secrets:**

- `HETZNER_SSH_HOST` - Server IP
- `HETZNER_SSH_USER` - SSH user (root)
- `HETZNER_SSH_KEY` - Private SSH key
- `OP_SERVICE_ACCOUNT_TOKEN` - 1Password service account token

**Manual trigger:**

```bash
# Push to main branch
git push origin main

# Or trigger manually in GitHub Actions
```

## Troubleshooting

### Secrets not loading

```bash
# Check 1Password CLI
op --version

# Check authentication
op account list

# Test secrets script
cd /Users/rodneyhammad/Private/Gandalf-gate-docke/homelab
./.kamal/secrets
```

### Deployment fails

```bash
# Check server connection
kamal server exec whoami

# View full logs
kamal deploy --verbose

# Check hooks
bash -x .kamal/hooks/pre-deploy
```

### Permission denied

```bash
# Ensure hooks are executable
chmod +x .kamal/hooks/*
chmod +x .kamal/secrets
```

## Security Notes

1. **Never commit secrets** - Use `.gitignore` to exclude `.env` files
2. **Use 1Password CLI** - More secure than plain text files
3. **Rotate secrets regularly** - Update in 1Password vault
4. **Limit access** - Only authorized users should access the vault
5. **Use service accounts** - For CI/CD (GitHub Actions)

## Learn More

- [Kamal Documentation](https://kamal-deploy.org/)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
