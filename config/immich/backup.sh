#!/bin/bash
##############################################################################
# IMMICH BACKUP SCRIPT
# Comprehensive backup solution for Immich photo management
# Best practices: Database + Media + Configuration backups
##############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - Adjust these to match your setup
BACKUP_BASE_DIR="${IMMICH_BACKUP_DIR:-./backups/immich}"
DB_CONTAINER_NAME="immich-postgres"
DB_USER="postgres"
DB_NAME="immich"
RETENTION_DAYS="${IMMICH_BACKUP_RETENTION_DAYS:-7}"
REMOTE_BACKUP_ENABLED="${IMMICH_REMOTE_BACKUP_ENABLED:-false}"
REMOTE_USER="${IMMICH_REMOTE_USER:-}"
REMOTE_HOST="${IMMICH_REMOTE_HOST:-}"
REMOTE_DIR="${IMMICH_REMOTE_DIR:-/backups/immich}"

# Timestamp for this backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE_DIR}/${TIMESTAMP}"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create backup directory structure
create_backup_dirs() {
    log "Creating backup directory structure..."
    mkdir -p "${BACKUP_DIR}"/{database,media,config}
    mkdir -p "${BACKUP_BASE_DIR}"/logs
}

# Backup PostgreSQL database
backup_database() {
    log "Starting database backup..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
        error "Database container '${DB_CONTAINER_NAME}' is not running!"
        return 1
    fi

    # Create database dump
    docker exec "${DB_CONTAINER_NAME}" pg_dump \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        --format=custom \
        --no-owner \
        --no-acl \
        > "${BACKUP_DIR}/database/immich_db_${TIMESTAMP}.dump" 2>"${BACKUP_BASE_DIR}/logs/db_backup_${TIMESTAMP}.log"

    if [ $? -eq 0 ]; then
        log "Database backup completed successfully"
        # Also create a plain SQL dump for easy inspection
        docker exec "${DB_CONTAINER_NAME}" pg_dump \
            -U "${DB_USER}" \
            -d "${DB_NAME}" \
            --no-owner \
            --no-acl \
            > "${BACKUP_DIR}/database/immich_db_${TIMESTAMP}.sql" 2>>"${BACKUP_BASE_DIR}/logs/db_backup_${TIMESTAMP}.log"
        return 0
    else
        error "Database backup failed! Check logs: ${BACKUP_BASE_DIR}/logs/db_backup_${TIMESTAMP}.log"
        return 1
    fi
}

# Backup media files from Docker volume
backup_media() {
    log "Starting media assets backup..."

    # Create a temporary container to access the volume
    TEMP_CONTAINER="immich-backup-${TIMESTAMP}"

    docker run --rm \
        --name "${TEMP_CONTAINER}" \
        --volumes-from immich-server \
        -v "${BACKUP_DIR}/media:/backup" \
        alpine:latest \
        sh -c "cd /usr/src/app/upload && tar czf /backup/immich_media_${TIMESTAMP}.tar.gz ." \
        2>"${BACKUP_BASE_DIR}/logs/media_backup_${TIMESTAMP}.log"

    if [ $? -eq 0 ]; then
        log "Media assets backup completed successfully"
        return 0
    else
        error "Media assets backup failed! Check logs: ${BACKUP_BASE_DIR}/logs/media_backup_${TIMESTAMP}.log"
        return 1
    fi
}

# Backup configuration files
backup_config() {
    log "Backing up configuration files..."

    # Backup docker-compose file
    if [ -f "docker-compose.immich.yml" ]; then
        cp docker-compose.immich.yml "${BACKUP_DIR}/config/"
    fi

    # Backup environment variables (sanitized)
    if [ -f ".env" ]; then
        # Remove sensitive data before backing up
        grep -v -E "^(PASSWORD|SECRET|KEY|TOKEN)=" .env > "${BACKUP_DIR}/config/.env.sanitized" 2>/dev/null || true
    fi

    # Backup Immich config directory if it exists
    if [ -d "config/immich" ]; then
        tar czf "${BACKUP_DIR}/config/immich_config_${TIMESTAMP}.tar.gz" -C config/immich . 2>/dev/null || true
    fi

    log "Configuration backup completed"
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."
    
    cat > "${BACKUP_DIR}/manifest.txt" <<EOF
Immich Backup Manifest
======================
Timestamp: ${TIMESTAMP}
Date: $(date)
Backup Directory: ${BACKUP_DIR}

Contents:
- Database: immich_db_${TIMESTAMP}.dump (PostgreSQL custom format)
- Database: immich_db_${TIMESTAMP}.sql (Plain SQL format)
- Media: immich_media_${TIMESTAMP}.tar.gz
- Configuration: immich_config_${TIMESTAMP}.tar.gz (if exists)

Backup Size:
$(du -sh "${BACKUP_DIR}" | awk '{print $1}')

Verification:
- Database dump: $(test -f "${BACKUP_DIR}/database/immich_db_${TIMESTAMP}.dump" && echo "✓ Present" || echo "✗ Missing")
- Media archive: $(test -f "${BACKUP_DIR}/media/immich_media_${TIMESTAMP}.tar.gz" && echo "✓ Present" || echo "✗ Missing")
EOF

    log "Manifest created: ${BACKUP_DIR}/manifest.txt"
}

# Sync to remote location (optional)
sync_remote() {
    if [ "${REMOTE_BACKUP_ENABLED}" != "true" ]; then
        return 0
    fi

    if [ -z "${REMOTE_USER}" ] || [ -z "${REMOTE_HOST}" ]; then
        warn "Remote backup enabled but REMOTE_USER or REMOTE_HOST not set. Skipping remote sync."
        return 0
    fi

    log "Syncing backup to remote server..."

    rsync -avz --progress \
        "${BACKUP_DIR}/" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/${TIMESTAMP}/" \
        2>"${BACKUP_BASE_DIR}/logs/remote_sync_${TIMESTAMP}.log"

    if [ $? -eq 0 ]; then
        log "Remote sync completed successfully"
        return 0
    else
        error "Remote sync failed! Check logs: ${BACKUP_BASE_DIR}/logs/remote_sync_${TIMESTAMP}.log"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."

    find "${BACKUP_BASE_DIR}" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true

    log "Cleanup completed"
}

# Main backup function
main() {
    log "========================================="
    log "Starting Immich Backup Process"
    log "========================================="

    create_backup_dirs

    # Run backups
    DB_SUCCESS=true
    MEDIA_SUCCESS=true

    backup_database || DB_SUCCESS=false
    backup_media || MEDIA_SUCCESS=false
    backup_config
    create_manifest

    # Remote sync if enabled
    if [ "${REMOTE_BACKUP_ENABLED}" = "true" ]; then
        sync_remote || warn "Remote sync had issues, but local backup completed"
    fi

    # Cleanup old backups
    cleanup_old_backups

    # Summary
    log "========================================="
    if [ "${DB_SUCCESS}" = "true" ] && [ "${MEDIA_SUCCESS}" = "true" ]; then
        log "Backup completed successfully!"
        log "Backup location: ${BACKUP_DIR}"
        log "Total size: $(du -sh "${BACKUP_DIR}" | awk '{print $1}')"
        exit 0
    else
        error "Backup completed with errors!"
        [ "${DB_SUCCESS}" = "false" ] && error "- Database backup failed"
        [ "${MEDIA_SUCCESS}" = "false" ] && error "- Media backup failed"
        exit 1
    fi
}

# Run main function
main "$@"
