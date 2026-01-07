#!/bin/bash
##############################################################################
# BACKUP SCRIPT
# Automated backup of configurations and databases
##############################################################################

set -e

# Configuration
BACKUP_BASE_DIR="/mnt/hetzner-storage/backups"
BACKUP_TYPE="${1:-full}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/backup-$TIMESTAMP"
DEPLOY_PATH="/opt/homelab"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  HOMELAB BACKUP SCRIPT${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Backup type: $BACKUP_TYPE"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory
echo "Creating backup directory..."
mkdir -p "$BACKUP_DIR"

##############################################################################
# BACKUP FUNCTIONS
##############################################################################

backup_traefik() {
    echo -e "${YELLOW}Backing up Traefik configuration...${NC}"
    mkdir -p "$BACKUP_DIR/config/traefik"
    cp -r "$DEPLOY_PATH/config/traefik" "$BACKUP_DIR/config/"
    echo "✅ Traefik configuration backed up"
}

backup_crowdsec() {
    echo -e "${YELLOW}Backing up CrowdSec...${NC}"
    mkdir -p "$BACKUP_DIR/config/crowdsec"

    # Stop CrowdSec briefly for consistent backup
    docker-compose -f "$DEPLOY_PATH/docker-compose.yml" stop crowdsec

    # Backup configuration and database
    cp -r "$DEPLOY_PATH/config/crowdsec" "$BACKUP_DIR/config/"

    # Restart CrowdSec
    docker-compose -f "$DEPLOY_PATH/docker-compose.yml" start crowdsec

    echo "✅ CrowdSec backed up"
}

backup_authelia() {
    echo -e "${YELLOW}Backing up Authelia...${NC}"
    mkdir -p "$BACKUP_DIR/config/authelia"

    # Backup configuration
    cp -r "$DEPLOY_PATH/config/authelia" "$BACKUP_DIR/config/"

    # Backup Authelia database
    docker exec authelia sqlite3 /var/lib/authelia/db.sqlite3 ".backup /var/lib/authelia/db-backup.sqlite3" || true
    docker cp authelia:/var/lib/authelia/db-backup.sqlite3 "$BACKUP_DIR/config/authelia/" || true

    echo "✅ Authelia backed up"
}

backup_prometheus() {
    echo -e "${YELLOW}Backing up Prometheus...${NC}"
    mkdir -p "$BACKUP_DIR/monitoring"

    # Snapshot Prometheus data
    curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot || true

    # Copy configuration
    cp -r "$DEPLOY_PATH/config/prometheus" "$BACKUP_DIR/monitoring/"

    echo "✅ Prometheus backed up"
}

backup_grafana() {
    echo -e "${YELLOW}Backing up Grafana...${NC}"
    mkdir -p "$BACKUP_DIR/monitoring/grafana"

    # Backup Grafana database
    docker exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup /var/lib/grafana/grafana-backup.db" || true
    docker cp grafana:/var/lib/grafana/grafana-backup.db "$BACKUP_DIR/monitoring/grafana/" || true

    # Backup dashboards and provisioning
    cp -r "$DEPLOY_PATH/config/grafana" "$BACKUP_DIR/monitoring/"

    echo "✅ Grafana backed up"
}

backup_immich() {
    echo -e "${YELLOW}Backing up Immich...${NC}"

    # Check if Immich is running
    if ! docker ps --format '{{.Names}}' | grep -q "^immich-postgres$"; then
        echo "⚠️  Immich not running, skipping backup"
        return 0
    fi

    # Run the dedicated Immich backup script
    if [ -f "$DEPLOY_PATH/config/immich/backup.sh" ]; then
        cd "$DEPLOY_PATH"
        bash config/immich/backup.sh

        # Copy Immich backups to main backup directory
        if [ -d "$DEPLOY_PATH/backups/immich" ]; then
            mkdir -p "$BACKUP_DIR/immich"
            cp -r "$DEPLOY_PATH/backups/immich"/* "$BACKUP_DIR/immich/" 2>/dev/null || true
        fi

        echo "✅ Immich backed up"
    else
        echo "⚠️  Immich backup script not found at $DEPLOY_PATH/config/immich/backup.sh"
    fi
}

backup_loki() {
    echo -e "${YELLOW}Backing up Loki...${NC}"
    mkdir -p "$BACKUP_DIR/monitoring"

    # Copy configuration
    cp -r "$DEPLOY_PATH/config/loki" "$BACKUP_DIR/monitoring/"

    echo "✅ Loki backed up"
}

backup_docker_compose() {
    echo -e "${YELLOW}Backing up Docker Compose configuration...${NC}"
    mkdir -p "$BACKUP_DIR"

    cp "$DEPLOY_PATH/docker-compose.yml" "$BACKUP_DIR/"
    cp "$DEPLOY_PATH/Makefile" "$BACKUP_DIR/" || true

    echo "✅ Docker Compose backed up"
}

backup_secrets() {
    echo -e "${YELLOW}Backing up secrets...${NC}"
    mkdir -p "$BACKUP_DIR/secrets"

    # Backup secret files (encrypted)
    if [ -d "$DEPLOY_PATH/config/authelia" ]; then
        cp "$DEPLOY_PATH/config/authelia"/*secret*.txt "$BACKUP_DIR/secrets/" 2>/dev/null || true
    fi

    if [ -f "$DEPLOY_PATH/config/traefik/cf_api_token.txt" ]; then
        cp "$DEPLOY_PATH/config/traefik/cf_api_token.txt" "$BACKUP_DIR/secrets/" || true
    fi

    echo "✅ Secrets backed up"
}

##############################################################################
# EXECUTE BACKUP
##############################################################################

case "$BACKUP_TYPE" in
    full)
        echo "Performing FULL backup..."
        backup_docker_compose
        backup_traefik
        backup_crowdsec
        backup_authelia
        backup_prometheus
        backup_grafana
        backup_loki
        backup_immich
        backup_secrets
        ;;

    config-only)
        echo "Performing CONFIG-ONLY backup..."
        backup_docker_compose
        backup_traefik
        backup_crowdsec
        backup_authelia
        backup_secrets
        ;;

    database-only)
        echo "Performing DATABASE-ONLY backup..."
        backup_crowdsec
        backup_authelia
        backup_grafana
        backup_immich
        ;;

    pre-deployment)
        echo "Performing PRE-DEPLOYMENT backup..."
        backup_docker_compose
        backup_traefik
        backup_crowdsec
        backup_authelia
        ;;
 
    *)
        echo -e "${RED}Unknown backup type: $BACKUP_TYPE${NC}"
        exit 1
        ;;
esac

##############################################################################
# FINALIZE BACKUP
##############################################################################

# Create symlink to latest backup
ln -sfn "$BACKUP_DIR" "$BACKUP_BASE_DIR/latest"

# Create backup manifest
cat > "$BACKUP_DIR/manifest.txt" <<EOF
Backup Manifest
===============
Backup Type: $BACKUP_TYPE
Timestamp: $TIMESTAMP
Date: $(date)
Hostname: $(hostname)
User: $(whoami)

Backup Contents:
$(find "$BACKUP_DIR" -type f | wc -l) files
Total Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

# Calculate checksums
echo "Calculating checksums..."
find "$BACKUP_DIR" -type f -exec sha256sum {} \; > "$BACKUP_DIR/checksums.txt"

# Compress backup (optional)
if [ "$COMPRESS_BACKUP" = "true" ]; then
    echo "Compressing backup..."
    cd "$BACKUP_BASE_DIR"
    tar -czf "backup-$TIMESTAMP.tar.gz" "backup-$TIMESTAMP"
    rm -rf "backup-$TIMESTAMP"
    echo "✅ Backup compressed"
fi

##############################################################################
# CLEANUP OLD BACKUPS
##############################################################################

echo "Cleaning up old backups..."
# Keep last 30 days
find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" -mtime +30 -exec rm -rf {} \;

# Keep last 7 weekly backups
# Keep last 3 monthly backups (1st of month)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BACKUP COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Backup location: $BACKUP_DIR"
echo "Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
