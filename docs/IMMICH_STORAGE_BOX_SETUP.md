# Immich Storage Box Setup

This guide explains how to set up the dedicated Storage Box for Immich photo management.

## Storage Box Details

- **Server**: `u527847.your-storagebox.de`
- **Username**: `u527847`
- **Samba/CIFS Share**: `//u527847.your-storagebox.de/backup`
- **SSH Port**: `23`
- **Mount Point**: `/mnt/storagebox-immich`

## Environment Variables

Add to `.env` file:

```bash
# Immich Storage Box
IMMICH_SB_HOST=u527847.your-storagebox.de
IMMICH_SB_USER=u527847
IMMICH_SB_PASSWORD=your_password_here
```

## Mount Options

### Option 1: WebDAV (Recommended)

WebDAV is the recommended method for mounting the Storage Box.

#### Setup WebDAV Mount

1. **Install davfs2**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y davfs2
   ```

2. **Create mount point**:
   ```bash
   sudo mkdir -p /mnt/storagebox-immich
   sudo chown root:root /mnt/storagebox-immich
   sudo chmod 755 /mnt/storagebox-immich
   ```

3. **Configure credentials**:
   ```bash
   sudo nano /etc/davfs2/secrets
   ```
   
   Add the following line:
   ```
   https://u527847.your-storagebox.de u527847 your_password
   ```
   
   Set proper permissions:
   ```bash
   sudo chmod 600 /etc/davfs2/secrets
   ```

4. **Add to /etc/fstab**:
   ```
   https://u527847.your-storagebox.de /mnt/storagebox-immich davfs uid=1000,gid=1000,file_mode=0770,dir_mode=0770,noexec,nosuid,nodev,_netdev 0 0
   ```

5. **Mount**:
   ```bash
   sudo mount /mnt/storagebox-immich
   ```

6. **Verify**:
   ```bash
   df -h | grep storagebox-immich
   ls -lah /mnt/storagebox-immich/
   ```

### Option 2: SSHFS

SSHFS is an alternative method using SSH.

1. **Install sshfs**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y sshfs
   ```

2. **Create mount point**:
   ```bash
   sudo mkdir -p /mnt/storagebox-immich
   sudo chown 1000:1000 /mnt/storagebox-immich
   ```

3. **Setup SSH key** (recommended):
   ```bash
   sudo ssh-keygen -t ed25519 -f /root/.ssh/immich-storagebox -N ""
   sudo ssh-copy-id -i /root/.ssh/immich-storagebox -p 23 u527847@u527847.your-storagebox.de
   ```

4. **Add to /etc/fstab**:
   ```
   u527847@u527847.your-storagebox.de:/ /mnt/storagebox-immich fuse.sshfs _netdev,user,idmap=user,transform_symlinks,IdentityFile=/root/.ssh/immich-storagebox,allow_other,default_permissions,uid=1000,gid=1000,port=23,StrictHostKeyChecking=no 0 0
   ```

5. **Mount**:
   ```bash
   sudo mount /mnt/storagebox-immich
   ```

### Option 3: CIFS/SMB

CIFS/SMB can be used but is generally slower than WebDAV or SSHFS.

1. **Install cifs-utils**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y cifs-utils
   ```

2. **Create credentials file**:
   ```bash
   sudo nano /root/.smb-credentials-immich
   ```
   
   Add:
   ```
   username=u527847
   password=your_password
   domain=u527847
   ```
   
   Set permissions:
   ```bash
   sudo chmod 600 /root/.smb-credentials-immich
   ```

3. **Create mount point**:
   ```bash
   sudo mkdir -p /mnt/storagebox-immich
   ```

4. **Add to /etc/fstab**:
   ```
   //u527847.your-storagebox.de/backup /mnt/storagebox-immich cifs credentials=/root/.smb-credentials-immich,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,vers=3.0,sec=ntlmv2,_netdev 0 0
   ```

5. **Mount**:
   ```bash
   sudo mount /mnt/storagebox-immich
   ```

## Systemd Service (Auto-mount on Boot)

Create a systemd service for automatic mounting:

```bash
sudo nano /etc/systemd/system/storagebox-immich-mount.service
```

Add:

```ini
[Unit]
Description=Mount Immich Storage Box
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/mount /mnt/storagebox-immich
ExecStop=/bin/umount /mnt/storagebox-immich
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable storagebox-immich-mount.service
sudo systemctl start storagebox-immich-mount.service
```

## Verify Setup

1. **Check mount status**:
   ```bash
   mount | grep storagebox-immich
   df -h | grep storagebox-immich
   ```

2. **Test write permissions** (if needed):
   ```bash
   touch /mnt/storagebox-immich/test.txt && rm /mnt/storagebox-immich/test.txt
   ```

3. **Check Docker volume**:
   ```bash
   docker volume inspect homelab_immich-storagebox
   ```

## Directory Structure

Recommended directory structure on the Storage Box:

```
/mnt/storagebox-immich/
├── photos/          # Original photos
├── videos/          # Original videos
├── thumbnails/      # Generated thumbnails (optional)
└── backups/         # Immich database backups
```

## Troubleshooting

### Mount fails on boot
- Check network connectivity: `ping u527847.your-storagebox.de`
- Verify credentials: `cat /etc/davfs2/secrets` (for WebDAV)
- Check logs: `journalctl -u storagebox-immich-mount.service`

### Permission denied
- Verify mount point ownership: `ls -ld /mnt/storagebox-immich`
- Check fstab options: `uid=1000,gid=1000`

### Connection timeout
- Verify firewall rules allow outbound connections
- Check SSH port (23) is accessible
- Test connection: `ssh -p 23 u527847@u527847.your-storagebox.de`

## Notes

- The Storage Box is mounted as **read-only** (`:ro`) in the Immich container for accessing existing media
- New uploads go to the `immich-uploads` Docker volume (internal storage)
- This Storage Box is **separate** from the main `hetzner-media` Storage Box used by Jellyfin, Navidrome, etc.

