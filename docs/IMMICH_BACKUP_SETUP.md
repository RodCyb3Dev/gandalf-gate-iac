# Immich Backup Setup

This guide explains how the Immich backup script works and how to schedule it.

## How It Works

The Immich backup script (`config/immich/backup.sh`) **runs on the host**, not inside the Immich container. It uses `docker exec` commands to interact with the containers:

1. **Database Backup**: Uses `docker exec immich-postgres pg_dump` to create PostgreSQL dumps
2. **Media Backup**: Uses a temporary container to access the `immich-uploads` volume
3. **Configuration Backup**: Copies docker-compose files and sanitized .env

## Integration with Main Backup System

The Immich backup is integrated into the main backup script (`scripts/backup.sh`):

- **Full Backup**: Includes Immich backups automatically
- **Database-Only Backup**: Includes Immich database backups
- **Config-Only Backup**: Does not include Immich (media backups are large)

## Scheduling Options

### Option 1: Systemd Timer (Recommended)

Systemd timers provide better logging and dependency management.

1. **Copy service and timer files**:
   ```bash
   sudo cp systemd/immich-backup.service /etc/systemd/system/
   sudo cp systemd/immich-backup.timer /etc/systemd/system/
   ```

2. **Enable and start the timer**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable immich-backup.timer
   sudo systemctl start immich-backup.timer
   ```

3. **Check status**:
   ```bash
   # Check timer status
   sudo systemctl status immich-backup.timer
   
   # Check last run
   sudo systemctl status immich-backup.service
   
   # View logs
   sudo journalctl -u immich-backup.service -f
   ```

4. **Manual trigger** (for testing):
   ```bash
   sudo systemctl start immich-backup.service
   ```

### Option 2: Cron

Simple cron-based scheduling.

1. **Edit crontab**:
   ```bash
   crontab -e
   ```

2. **Add entry** (daily at 2 AM):
   ```cron
   0 2 * * * /opt/homelab/config/immich/backup.sh >> /opt/homelab/backups/immich/logs/cron.log 2>&1
   ```

3. **Or with environment variables**:
   ```cron
   0 2 * * * cd /opt/homelab && IMMICH_BACKUP_DIR=/opt/homelab/backups/immich IMMICH_BACKUP_RETENTION_DAYS=7 /opt/homelab/config/immich/backup.sh >> /opt/homelab/backups/immich/logs/cron.log 2>&1
   ```

### Option 3: GitHub Actions

The Immich backup is automatically included when running the main backup workflow (`.github/workflows/backup.yml`).

The workflow runs:
- **Daily at 3:00 AM UTC** (scheduled)
- **Manually** via workflow_dispatch

## Configuration

### Environment Variables

Set these in the systemd service file or in your shell:

```bash
# Backup directory (default: ./backups/immich)
export IMMICH_BACKUP_DIR="/opt/homelab/backups/immich"

# Retention days (default: 7)
export IMMICH_BACKUP_RETENTION_DAYS=30

# Remote backup (optional)
export IMMICH_REMOTE_BACKUP_ENABLED=true
export IMMICH_REMOTE_USER="backup-user"
export IMMICH_REMOTE_HOST="backup.server"
export IMMICH_REMOTE_DIR="/backups/immich"
```

### Backup Locations

- **Local Backups**: `/opt/homelab/backups/immich/YYYYMMDD_HHMMSS/`
- **Logs**: `/opt/homelab/backups/immich/logs/`
- **Main Backup Integration**: Backups are copied to `/mnt/hetzner-storage/backups/backup-YYYYMMDD_HHMMSS/immich/` when running full backup

## Manual Execution

Run the backup script manually:

```bash
# From the homelab directory
cd /opt/homelab

# Basic run (uses defaults)
./config/immich/backup.sh

# With custom settings
IMMICH_BACKUP_DIR=/path/to/backups \
IMMICH_BACKUP_RETENTION_DAYS=30 \
./config/immich/backup.sh
```

## What Gets Backed Up

1. **Database**:
   - PostgreSQL custom format dump (`.dump`)
   - Plain SQL dump (`.sql`)

2. **Media**:
   - All files from `immich-uploads` volume
   - Compressed as `.tar.gz`

3. **Configuration**:
   - `docker-compose.immich.yml`
   - Sanitized `.env` (passwords removed)
   - Immich config directory (if exists)

4. **Manifest**:
   - Backup verification manifest
   - File checksums

## Verification

Check backup integrity:

```bash
# List backups
ls -lh /opt/homelab/backups/immich/

# View manifest
cat /opt/homelab/backups/immich/YYYYMMDD_HHMMSS/manifest.txt

# Verify checksums
cd /opt/homelab/backups/immich/YYYYMMDD_HHMMSS
sha256sum -c checksums.txt
```

## Troubleshooting

### Backup fails with "permission denied"
- Ensure the script is executable: `chmod +x config/immich/backup.sh`
- Check Docker socket permissions: `sudo usermod -aG docker deploy`

### Database container not found
- Verify Immich is running: `docker ps | grep immich`
- Check container name matches: `docker ps --format '{{.Names}}' | grep immich`

### Out of disk space
- Check available space: `df -h`
- Reduce retention: `IMMICH_BACKUP_RETENTION_DAYS=3`
- Enable remote backup to offload backups

### Systemd timer not running
- Check timer status: `sudo systemctl status immich-backup.timer`
- Check service logs: `sudo journalctl -u immich-backup.service`
- Verify timer is enabled: `sudo systemctl is-enabled immich-backup.timer`

## Best Practices

1. **Test Backups Regularly**: Restore from backup to verify integrity
2. **Monitor Disk Space**: Immich backups can be large (especially media)
3. **Use Remote Backups**: Store backups off-site for disaster recovery
4. **Retention Policy**: Adjust `IMMICH_BACKUP_RETENTION_DAYS` based on storage capacity
5. **Schedule Off-Peak**: Run backups during low-usage hours (e.g., 2-3 AM)

