#!/bin/bash
# Test script to verify 1Password secrets are accessible

set -e

echo "🔐 Testing 1Password Secrets Access"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VAULT="homelab-env"

# Check if op is installed
if ! command -v op &> /dev/null; then
    echo -e "${RED}❌ 1Password CLI not found${NC}"
    echo "Install with: brew install --cask 1password-cli"
    exit 1
fi
echo -e "${GREEN}✅ 1Password CLI installed${NC}"

# Check if signed in
if ! op account list &> /dev/null; then
    echo -e "${RED}❌ Not signed in to 1Password${NC}"
    echo "Run: eval \$(op signin)"
    exit 1
fi
echo -e "${GREEN}✅ Signed in to 1Password${NC}"

# List all vaults
echo ""
echo "📦 Available vaults:"
op vault list || {
    echo -e "${RED}❌ Failed to list vaults. Try: eval \$(op signin)${NC}"
    exit 1
}

# Check if homelab-env vault exists
echo ""
if op vault get "$VAULT" &> /dev/null; then
    echo -e "${GREEN}✅ Vault '$VAULT' exists${NC}"
else
    echo -e "${RED}❌ Vault '$VAULT' not found${NC}"
    echo ""
    echo "Create with: op vault create $VAULT"
    exit 1
fi

# List items in vault
echo ""
echo "📋 Items in '$VAULT' vault:"
op item list --vault "$VAULT" --format=json | jq -r '.[] | "  - \(.title)"' || {
    echo -e "${YELLOW}⚠️  No items found or jq not installed${NC}"
    op item list --vault "$VAULT"
}

# Test fetching specific secrets
echo ""
echo "🔍 Testing secret retrieval..."
echo ""

SECRETS=(
    "DOMAIN"
    "CF_API_EMAIL"
    "CF_API_KEY"
    "TS_AUTHKEY"
    "AUTHELIA_JWT_SECRET"
    "GRAFANA_ADMIN_PASSWORD"
    "KAMAL_REGISTRY_USERNAME"
    "KAMAL_REGISTRY_PASSWORD"
)

for secret in "${SECRETS[@]}"; do
    if op item get "$secret" --vault "$VAULT" &> /dev/null; then
        # Try to get the password field
        value=$(op item get "$secret" --vault "$VAULT" --fields password 2>/dev/null || echo "")
        if [ -n "$value" ]; then
            echo -e "${GREEN}✅ $secret${NC} - Found (${#value} characters)"
        else
            echo -e "${YELLOW}⚠️  $secret${NC} - Item exists but 'password' field is empty"
            echo "   Available fields:"
            op item get "$secret" --vault "$VAULT" --format=json | jq -r '.fields[] | "     - \(.label): \(.type)"'
        fi
    else
        echo -e "${RED}❌ $secret${NC} - Not found"
    fi
done

echo ""
echo "🧪 Testing full secrets script..."
cd "$(dirname "$0")/.."
if ./.kamal/secrets >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Secrets script executed successfully${NC}"
    echo ""
    echo "📊 Secret values loaded (first 50 chars):"
    ./.kamal/secrets 2>/dev/null | head -10 | while IFS='=' read -r key value; do
        if [ -n "$value" ]; then
            echo -e "${GREEN}  ✅ $key${NC}=${value:0:20}..."
        else
            echo -e "${RED}  ❌ $key${NC}=(empty)"
        fi
    done
else
    echo -e "${RED}❌ Secrets script failed${NC}"
    echo ""
    echo "Run with output:"
    ./.kamal/secrets
fi

echo ""
echo "✅ Testing complete!"
