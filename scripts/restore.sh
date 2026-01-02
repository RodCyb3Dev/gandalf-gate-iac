#!/bin/bash
##############################################################################
# RESTORE SCRIPT
# Restore from backup
##############################################################################

set -e

# Configuration
BACKUP_BASE_DIR="/mnt/hetzner-storage/backups"
BACKUP_TYPE="${1:-latest}"
DEPLOY_PATH="/opt/homelab"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  HOMELAB RESTORE SCRIPT${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

##############################################################################
# SELECT BACKUP
##############################################################################

if [ "$BACKUP_TYPE" = "latest" ]; then
    BACKUP_DIR="$BACKUP_BASE_DIR/latest"
    echo "Using latest backup..."
elif [ "$BACKUP_TYPE" = "pre-deployment" ]; then
    BACKUP_DIR=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" | sort -r | head -1)
    echo "Using latest pre-deployment backup..."
else
    BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_TYPE"
    echo "Using specified backup: $BACKUP_TYPE"
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

echo "Backup directory: $BACKUP_DIR"
echo ""

# Show backup manifest
if [ -f "$BACKUP_DIR/manifest.txt" ]; then
    echo "Backup Manifest:"
    cat "$BACKUP_DIR/manifest.txt"
    echo ""
fi

# Confirmation
read -p "⚠️  Are you sure you want to restore from this backup? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

##############################################################################
# VERIFY CHECKSUMS
##############################################################################

if [ -f "$BACKUP_DIR/checksums.txt" ]; then
    echo "Verifying backup integrity..."
    cd "$BACKUP_DIR"
    if sha256sum -c checksums.txt --quiet; then
        echo "✅ Backup integrity verified"
    else
        echo -e "${RED}❌ Backup integrity check failed!${NC}"
        read -p "Continue anyway? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            exit 1
        fi
    fi
fi

##############################################################################
# STOP SERVICES
##############################################################################

echo "Stopping services..."
cd "$DEPLOY_PATH"
docker-compose stop

##############################################################################
# RESTORE FILES
##############################################################################

restore_traefik() {
    echo -e "${YELLOW}Restoring Traefik...${NC}"
    cp -r "$BACKUP_DIR/config/traefik" "$DEPLOY_PATH/config/"
    chmod 600 "$DEPLOY_PATH/config/traefik/acme.json"
    echo "✅ Traefik restored"
}

restore_crowdsec() {
    echo -e "${YELLOW}Restoring CrowdSec...${NC}"
    cp -r "$BACKUP_DIR/config/crowdsec" "$DEPLOY_PATH/config/"
    echo "✅ CrowdSec restored"
}

restore_authelia() {
    echo -e "${YELLOW}Restoring Authelia...${NC}"
    cp -r "$BACKUP_DIR/config/authelia" "$DEPLOY_PATH/config/"
    
    # Restore database
    if [ -f "$BACKUP_DIR/config/authelia/db-backup.sqlite3" ]; then
        docker cp "$BACKUP_DIR/config/authelia/db-backup.sqlite3" authelia:/var/lib/authelia/db.sqlite3
    fi
    
    echo "✅ Authelia restored"
}

restore_grafana() {
    echo -e "${YELLOW}Restoring Grafana...${NC}"
    cp -r "$BACKUP_DIR/monitoring/grafana" "$DEPLOY_PATH/config/"
    
    # Restore database
    if [ -f "$BACKUP_DIR/monitoring/grafana/grafana-backup.db" ]; then
        docker cp "$BACKUP_DIR/monitoring/grafana/grafana-backup.db" grafana:/var/lib/grafana/grafana.db
    fi
    
    echo "✅ Grafana restored"
}

restore_docker_compose() {
    echo -e "${YELLOW}Restoring Docker Compose...${NC}"
    cp "$BACKUP_DIR/docker-compose.yml" "$DEPLOY_PATH/"
    cp "$BACKUP_DIR/Makefile" "$DEPLOY_PATH/" || true
    echo "✅ Docker Compose restored"
}

restore_secrets() {
    echo -e "${YELLOW}Restoring secrets...${NC}"
    if [ -d "$BACKUP_DIR/secrets" ]; then
        cp "$BACKUP_DIR/secrets"/* "$DEPLOY_PATH/config/authelia/" 2>/dev/null || true
        cp "$BACKUP_DIR/secrets"/* "$DEPLOY_PATH/config/traefik/" 2>/dev/null || true
    fi
    echo "✅ Secrets restored"
}

##############################################################################
# EXECUTE RESTORE
##############################################################################

echo "Starting restore process..."
restore_docker_compose
restore_traefik
restore_crowdsec
restore_authelia
restore_grafana
restore_secrets

##############################################################################
# RESTART SERVICES
##############################################################################

echo "Restarting services..."
cd "$DEPLOY_PATH"
docker-compose up -d

# Wait for services to start
sleep 30

# Check service health
echo "Verifying service health..."
docker-compose ps

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RESTORE COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

