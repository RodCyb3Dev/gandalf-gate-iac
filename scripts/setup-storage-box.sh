#!/bin/bash
##############################################################################
# HETZNER STORAGE BOX SETUP SCRIPT
# Mount Storage Box and configure for media services
##############################################################################

set -e

# Configuration
STORAGE_BOX_HOST="u525677.your-storagebox.de"
STORAGE_BOX_USER="u525677"
STORAGE_BOX_SHARE="//u525677.your-storagebox.de/backup"
MOUNT_POINT="/mnt/hetzner-storage"
CREDENTIALS_FILE="/root/.storage-box-credentials"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HETZNER STORAGE BOX SETUP${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

##############################################################################
# CHECK REQUIREMENTS
##############################################################################

echo "Checking requirements..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

# Install required packages
if ! command -v mount.cifs &> /dev/null; then
    echo "Installing cifs-utils..."
    apt-get update
    apt-get install -y cifs-utils
fi

if ! command -v sshfs &> /dev/null; then
    echo "Installing sshfs..."
    apt-get install -y sshfs
fi

echo -e "${GREEN}✅ Requirements met${NC}"
echo ""

##############################################################################
# CONFIGURE MOUNT METHOD
##############################################################################

echo "Select mount method:"
echo "1) CIFS/SMB (recommended for Docker volumes)"
echo "2) SSHFS (better performance for direct access)"
read -p "Enter choice (1 or 2): " MOUNT_METHOD

##############################################################################
# SETUP CREDENTIALS
##############################################################################

echo ""
echo "Setting up credentials..."

if [ ! -f "$CREDENTIALS_FILE" ]; then
    read -p "Enter Storage Box password: " -s STORAGE_BOX_PASSWORD
    echo ""
    
    cat > "$CREDENTIALS_FILE" <<EOF
username=$STORAGE_BOX_USER
password=$STORAGE_BOX_PASSWORD
EOF
    
    chmod 600 "$CREDENTIALS_FILE"
    echo -e "${GREEN}✅ Credentials saved${NC}"
else
    echo -e "${YELLOW}Credentials file already exists${NC}"
fi

##############################################################################
# CREATE MOUNT POINT
##############################################################################

echo "Creating mount point..."
mkdir -p "$MOUNT_POINT"

##############################################################################
# MOUNT STORAGE BOX
##############################################################################

if [ "$MOUNT_METHOD" = "1" ]; then
    echo "Mounting via CIFS..."
    
    # Test connection
    if ! ping -c 1 "$STORAGE_BOX_HOST" &> /dev/null; then
        echo -e "${RED}❌ Cannot reach Storage Box host${NC}"
        exit 1
    fi
    
    # Mount
    mount -t cifs "$STORAGE_BOX_SHARE" "$MOUNT_POINT" \
        -o credentials="$CREDENTIALS_FILE",vers=3.0,sec=ntlmv2,uid=1000,gid=1000,file_mode=0777,dir_mode=0777
    
    # Add to fstab
    if ! grep -q "$STORAGE_BOX_SHARE" /etc/fstab; then
        echo "$STORAGE_BOX_SHARE $MOUNT_POINT cifs credentials=$CREDENTIALS_FILE,vers=3.0,sec=ntlmv2,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,_netdev 0 0" >> /etc/fstab
        echo -e "${GREEN}✅ Added to /etc/fstab${NC}"
    fi
    
elif [ "$MOUNT_METHOD" = "2" ]; then
    echo "Mounting via SSHFS..."
    
    # Setup SSH key if not exists
    if [ ! -f /root/.ssh/id_rsa ]; then
        echo "Generating SSH key..."
        ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
        
        echo ""
        echo -e "${YELLOW}Please add this public key to your Storage Box:${NC}"
        cat /root/.ssh/id_rsa.pub
        echo ""
        read -p "Press Enter once you've added the key..."
    fi
    
    # Mount
    sshfs -p 23 "${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}:" "$MOUNT_POINT" \
        -o allow_other,default_permissions,uid=1000,gid=1000
    
    # Add to fstab
    if ! grep -q "$STORAGE_BOX_HOST" /etc/fstab; then
        echo "${STORAGE_BOX_USER}@${STORAGE_BOX_HOST}: $MOUNT_POINT fuse.sshfs defaults,_netdev,allow_other,default_permissions,uid=1000,gid=1000,port=23 0 0" >> /etc/fstab
        echo -e "${GREEN}✅ Added to /etc/fstab${NC}"
    fi
fi

##############################################################################
# VERIFY MOUNT
##############################################################################

echo ""
echo "Verifying mount..."

if mountpoint -q "$MOUNT_POINT"; then
    echo -e "${GREEN}✅ Storage Box mounted successfully${NC}"
    
    # Show disk usage
    df -h "$MOUNT_POINT"
    
    # Test write access
    TEST_FILE="$MOUNT_POINT/test-write-$(date +%s).txt"
    if echo "test" > "$TEST_FILE" 2>/dev/null; then
        rm "$TEST_FILE"
        echo -e "${GREEN}✅ Write access confirmed${NC}"
    else
        echo -e "${RED}❌ Write access failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Mount failed${NC}"
    exit 1
fi

##############################################################################
# CREATE DIRECTORY STRUCTURE
##############################################################################

echo ""
echo "Creating directory structure..."

# Media directories
mkdir -p "$MOUNT_POINT/media/Movies"
mkdir -p "$MOUNT_POINT/media/TVShows"
mkdir -p "$MOUNT_POINT/media/Music"
mkdir -p "$MOUNT_POINT/media/Books"
mkdir -p "$MOUNT_POINT/media/Downloads"

# Backup directories
mkdir -p "$MOUNT_POINT/backups/configs"
mkdir -p "$MOUNT_POINT/backups/databases"

echo -e "${GREEN}✅ Directory structure created${NC}"

##############################################################################
# SETUP DOCKER VOLUME
##############################################################################

echo ""
echo "Setting up Docker volume..."

# The Docker volume is already defined in docker-compose.yml
# Just verify the mount point is accessible

if [ -d "$MOUNT_POINT/media" ]; then
    echo -e "${GREEN}✅ Docker can access Storage Box${NC}"
else
    echo -e "${RED}❌ Docker cannot access Storage Box${NC}"
    exit 1
fi

##############################################################################
# SETUP AUTOMATED MOUNT CHECK
##############################################################################

echo ""
echo "Setting up automated mount check..."

# Create systemd service to remount on failure
cat > /etc/systemd/system/storage-box-mount.service <<EOF
[Unit]
Description=Hetzner Storage Box Mount
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/mount -a
ExecStop=/bin/umount $MOUNT_POINT
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable storage-box-mount.service

echo -e "${GREEN}✅ Systemd service created${NC}"

##############################################################################
# SUMMARY
##############################################################################

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ STORAGE BOX SETUP COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Mount point: $MOUNT_POINT"
echo "Total space: $(df -h "$MOUNT_POINT" | awk 'NR==2 {print $2}')"
echo "Available: $(df -h "$MOUNT_POINT" | awk 'NR==2 {print $4}')"
echo ""
echo "Directory structure:"
echo "  - $MOUNT_POINT/media/       (media files)"
echo "  - $MOUNT_POINT/backups/     (backups)"
echo ""
echo "To unmount: umount $MOUNT_POINT"
echo "To remount: mount -a"
echo ""

