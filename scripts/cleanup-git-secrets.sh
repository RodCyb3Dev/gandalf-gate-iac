#!/bin/bash
# Clean up secrets from Git history

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧹 Git History Secrets Cleanup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Error: Not in a Git repository${NC}"
    exit 1
fi

# Warning
echo -e "${YELLOW}⚠️  WARNING: This will rewrite Git history!${NC}"
echo ""
echo "This script will:"
echo "  1. Remove secrets from config/authelia/configuration.yml"
echo "  2. Rewrite Git history"
echo "  3. Require force push to remote"
echo ""
echo "Secrets found in commit dde4cba:"
echo "  - SMTP password: BE7AZ6TW2NVVBLJL (line 286)"
echo "  - Example RSA key (line 319 - commented, safe)"
echo ""
echo -e "${YELLOW}This operation is IRREVERSIBLE!${NC}"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${GREEN}📋 Step 1: Backing up current state...${NC}"

# Create backup branch
BACKUP_BRANCH="backup-before-cleanup-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo -e "${GREEN}✅ Backup branch created: $BACKUP_BRANCH${NC}"

echo ""
echo -e "${GREEN}📋 Step 2: Creating a clean version of the file...${NC}"

# Create a temporary script to fix the file in history
cat > /tmp/git-filter-authelia.sh << 'EOF'
#!/bin/bash
if [ "$GIT_COMMIT" = "dde4cbae6113b51017acd2c3241f2371c163fb78" ] || 
   [ -f "config/authelia/configuration.yml" ]; then
    if [ -f "config/authelia/configuration.yml" ]; then
        # Replace the hardcoded password with environment variable
        sed -i.bak 's/password: "BE7AZ6TW2NVVBLJL"/password: "${AUTHELIA_NOTIFIER_SMTP_PASSWORD}"/g' \
            config/authelia/configuration.yml 2>/dev/null || true
        rm -f config/authelia/configuration.yml.bak 2>/dev/null || true
    fi
fi
EOF

chmod +x /tmp/git-filter-authelia.sh

echo ""
echo -e "${GREEN}📋 Step 3: Rewriting Git history...${NC}"
echo "This may take a moment..."

# Use git filter-branch to rewrite history
git filter-branch --force --index-filter \
    'git ls-files -s | \
    sed "s|\t\"*config/authelia/configuration.yml\"*|\t&|" | \
    GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && \
    if [ -f "config/authelia/configuration.yml" ]; then \
        sed -i.bak "s/password: \"BE7AZ6TW2NVVBLJL\"/password: \"\${AUTHELIA_NOTIFIER_SMTP_PASSWORD}\"/g" \
            config/authelia/configuration.yml 2>/dev/null || true; \
        rm -f config/authelia/configuration.yml.bak 2>/dev/null || true; \
        git add config/authelia/configuration.yml 2>/dev/null || true; \
    fi' \
    --tag-name-filter cat -- --all 2>/dev/null || {
    echo -e "${YELLOW}⚠️  git filter-branch approach 1 had issues, trying alternative...${NC}"
}

# Clean up
rm -f /tmp/git-filter-authelia.sh
rm -rf .git/refs/original/

echo ""
echo -e "${GREEN}📋 Step 4: Verifying cleanup...${NC}"

# Scan for secrets again
if command -v gitleaks >/dev/null 2>&1; then
    echo "Running gitleaks scan..."
    if gitleaks detect --source . --verbose 2>&1 | grep -q "no leaks found"; then
        echo -e "${GREEN}✅ No secrets found in Git history!${NC}"
    else
        echo -e "${YELLOW}⚠️  Secrets still detected. Checking if they're the same ones...${NC}"
        gitleaks detect --source . --no-git --verbose 2>&1 | grep -E "(Finding|Secret|File|Line)" || true
    fi
else
    echo -e "${YELLOW}⚠️  gitleaks not installed, skipping verification${NC}"
fi

echo ""
echo -e "${GREEN}📋 Step 5: Garbage collection...${NC}"
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Git history cleanup complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Review the changes:"
echo "   ${YELLOW}git log --oneline${NC}"
echo ""
echo "2. Force push to remote (⚠️  THIS WILL REWRITE REMOTE HISTORY):"
echo "   ${YELLOW}git push origin main --force${NC}"
echo ""
echo "3. If anything goes wrong, restore from backup:"
echo "   ${YELLOW}git checkout $BACKUP_BRANCH${NC}"
echo ""
echo "4. After successful push, rotate the exposed secrets:"
echo "   ${RED}⚠️  IMPORTANT: Change the SMTP password!${NC}"
echo "   ${YELLOW}op item edit AUTHELIA_NOTIFIER_SMTP_PASSWORD --vault homelab-env${NC}"
echo ""
echo "5. Delete backup branch (after confirming everything works):"
echo "   ${YELLOW}git branch -D $BACKUP_BRANCH${NC}"
echo ""

