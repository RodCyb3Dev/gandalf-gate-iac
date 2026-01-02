#!/bin/bash
# Setup 1Password vault with all required secrets

set -e

VAULT="homelab-env"

echo "🔐 Setting up 1Password vault: $VAULT"

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
    echo "❌ 1Password CLI not found. Install with: brew install --cask 1password-cli"
    exit 1
fi

# Check if signed in
if ! op account list &> /dev/null; then
    echo "🔑 Please sign in to 1Password..."
    op signin
fi

# Create vault if it doesn't exist
if ! op vault get "$VAULT" &> /dev/null; then
    echo "📦 Creating vault: $VAULT"
    op vault create "$VAULT"
else
    echo "✅ Vault $VAULT already exists"
fi

# Function to create or update item
create_secret() {
    local title=$1
    local value=$2
    
    # Check if item exists
    if op item get "$title" --vault "$VAULT" &> /dev/null; then
        echo "⚠️  Item '$title' already exists, skipping..."
    else
        echo "✅ Creating: $title"
        op item create --vault "$VAULT" --category=password --title="$title" password="$value"
    fi
}

echo ""
echo "📝 Creating secrets..."
echo ""

# Domain Configuration
read -p "Enter your domain (e.g., rodneyops.com): " DOMAIN
create_secret "DOMAIN" "$DOMAIN"

read -p "Enter Cloudflare email: " CF_EMAIL
create_secret "CF_API_EMAIL" "$CF_EMAIL"

read -p "Enter Cloudflare API key: " CF_KEY
create_secret "CF_API_KEY" "$CF_KEY"

# Tailscale
read -p "Enter Tailscale auth key: " TS_KEY
create_secret "TS_AUTHKEY" "$TS_KEY"

echo ""
echo "🔐 Generating secure secrets..."

# Authelia (auto-generate)
create_secret "AUTHELIA_JWT_SECRET" "$(openssl rand -base64 32)"
create_secret "AUTHELIA_SESSION_SECRET" "$(openssl rand -base64 32)"
create_secret "AUTHELIA_STORAGE_ENCRYPTION_KEY" "$(openssl rand -base64 32)"

read -p "Enter SMTP password for Authelia notifications (or press Enter to skip): " SMTP_PASS
if [ -n "$SMTP_PASS" ]; then
    create_secret "AUTHELIA_NOTIFIER_SMTP_PASSWORD" "$SMTP_PASS"
fi

# CrowdSec (auto-generate)
create_secret "CROWDSEC_BOUNCER_KEY" "$(openssl rand -hex 32)"

read -p "Enter CrowdSec enroll key (or press Enter to skip): " CS_ENROLL
if [ -n "$CS_ENROLL" ]; then
    create_secret "CROWDSEC_ENROLL_KEY" "$CS_ENROLL"
fi

# Grafana
create_secret "GRAFANA_ADMIN_USER" "admin"
create_secret "GRAFANA_ADMIN_PASSWORD" "$(openssl rand -base64 16)"

# Databases (auto-generate)
create_secret "POSTGRES_PASSWORD" "$(openssl rand -base64 16)"
create_secret "AUTHELIA_STORAGE_POSTGRES_PASSWORD" "$(openssl rand -base64 16)"
create_secret "REDIS_PASSWORD" "$(openssl rand -base64 16)"

# Hetzner Storage Box
echo ""
read -p "Enter Storage Box password: " STORAGE_PASS
create_secret "STORAGE_BOX_HOST" "u525677.your-storagebox.de"
create_secret "STORAGE_BOX_USER" "u525677"
create_secret "STORAGE_BOX_PASSWORD" "$STORAGE_PASS"

# Backup encryption (auto-generate)
create_secret "BACKUP_ENCRYPTION_KEY" "$(openssl rand -base64 32)"

# System settings
create_secret "PUID" "1000"
create_secret "PGID" "1000"
create_secret "TIMEZONE" "UTC"

# Docker Registry
echo ""
read -p "Enter Docker Hub username: " DOCKER_USER
read -p "Enter Docker Hub token/password: " DOCKER_PASS
create_secret "KAMAL_REGISTRY_USERNAME" "$DOCKER_USER"
create_secret "KAMAL_REGISTRY_PASSWORD" "$DOCKER_PASS"

echo ""
echo "✅ 1Password vault setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Verify secrets: op item list --vault $VAULT"
echo "2. Test secrets script: ./.kamal/secrets"
echo "3. Deploy with Kamal: make kamal-deploy"
echo ""
