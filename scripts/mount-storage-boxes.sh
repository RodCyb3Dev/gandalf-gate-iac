#!/bin/bash
##############################################################################
# MOUNT STORAGE BOXES - Mount both Hetzner Storage Boxes
# - Main Storage Box (u526046) → /mnt/storagebox (CIFS/SMB)
# - Immich Storage Box (u527847) → /mnt/storagebox-immich (WebDAV)
##############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Storage Box details
MAIN_SB_HOST="u526046.your-storagebox.de"
MAIN_SB_USER="u526046"
MAIN_SB_MOUNT="/mnt/storagebox"

IMMICH_SB_HOST="u527847.your-storagebox.de"
IMMICH_SB_USER="u527847"
IMMICH_SB_MOUNT="/mnt/storagebox-immich"

echo -e "${YELLOW}🗄️  Mounting Hetzner Storage Boxes${NC}"
echo ""

##############################################################################
# GET PASSWORDS
##############################################################################

# Main Storage Box password
if [ -z "${STORAGE_BOX_PASSWORD:-}" ]; then
    echo -e "${YELLOW}Enter password for main Storage Box (${MAIN_SB_USER}):${NC}"
    read -s MAIN_SB_PASSWORD
    echo ""
else
    MAIN_SB_PASSWORD="${STORAGE_BOX_PASSWORD}"
fi

# Immich Storage Box password
if [ -z "${IMMICH_SB_PASSWORD:-}" ]; then
    echo -e "${YELLOW}Enter password for Immich Storage Box (${IMMICH_SB_USER}):${NC}"
    read -s IMMICH_SB_PASSWORD
    echo ""
else
    IMMICH_SB_PASSWORD="${IMMICH_SB_PASSWORD}"
fi

##############################################################################
# MOUNT MAIN STORAGE BOX (CIFS/SMB)
##############################################################################

echo -e "${YELLOW}📦 Setting up main Storage Box (CIFS/SMB)...${NC}"

# Create credentials file
sudo tee /root/.smbcredentials > /dev/null <<EOF
username=${MAIN_SB_USER}
password=${MAIN_SB_PASSWORD}
domain=${MAIN_SB_USER}
EOF

sudo chmod 600 /root/.smbcredentials

# Ensure mount point exists
sudo mkdir -p "${MAIN_SB_MOUNT}"
sudo chown 1000:1000 "${MAIN_SB_MOUNT}"

# Add to fstab if not already present
if ! grep -q "${MAIN_SB_MOUNT}" /etc/fstab; then
    echo "//${MAIN_SB_HOST}/backup ${MAIN_SB_MOUNT} cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,file_mode=0770,dir_mode=0770,vers=3.0,sec=ntlmv2,_netdev 0 0" | sudo tee -a /etc/fstab > /dev/null
    echo -e "${GREEN}✅ Added main Storage Box to /etc/fstab${NC}"
else
    echo -e "${YELLOW}⚠️  Main Storage Box already in /etc/fstab${NC}"
fi

# Mount
if mountpoint -q "${MAIN_SB_MOUNT}"; then
    echo -e "${YELLOW}⚠️  Main Storage Box already mounted${NC}"
    sudo umount "${MAIN_SB_MOUNT}" || true
fi

# Wait a moment for any previous mount attempts to clear
sleep 2

# Try mounting with timeout
if timeout 30 sudo mount "${MAIN_SB_MOUNT}" 2>&1; then
    echo -e "${GREEN}✅ Main Storage Box mounted at ${MAIN_SB_MOUNT}${NC}"
else
    echo -e "${RED}❌ Failed to mount main Storage Box${NC}"
    echo -e "${YELLOW}⚠️  Trying alternative mount method (WebDAV)...${NC}"
    # Try WebDAV as fallback
    if ! grep -q "${MAIN_SB_HOST}" /etc/davfs2/secrets 2>/dev/null; then
        echo "https://${MAIN_SB_HOST} ${MAIN_SB_USER} ${MAIN_SB_PASSWORD}" | sudo tee -a /etc/davfs2/secrets > /dev/null
        sudo chmod 600 /etc/davfs2/secrets
    fi
    # Update fstab to use WebDAV
    sudo sed -i "\|${MAIN_SB_MOUNT}|d" /etc/fstab
    echo "https://${MAIN_SB_HOST} ${MAIN_SB_MOUNT} davfs uid=1000,gid=1000,file_mode=0770,dir_mode=0770,noexec,nosuid,nodev,_netdev 0 0" | sudo tee -a /etc/fstab > /dev/null
    if timeout 30 sudo mount "${MAIN_SB_MOUNT}" 2>&1; then
        echo -e "${GREEN}✅ Main Storage Box mounted via WebDAV at ${MAIN_SB_MOUNT}${NC}"
    else
        echo -e "${RED}❌ Failed to mount main Storage Box via WebDAV${NC}"
        exit 1
    fi
fi

##############################################################################
# MOUNT IMMICH STORAGE BOX (WebDAV)
##############################################################################

echo -e "${YELLOW}📸 Setting up Immich Storage Box (WebDAV)...${NC}"

# Configure davfs2
sudo mkdir -p /etc/davfs2

# Add credentials to davfs2 secrets
if ! grep -q "${IMMICH_SB_HOST}" /etc/davfs2/secrets 2>/dev/null; then
    echo "https://${IMMICH_SB_HOST} ${IMMICH_SB_USER} ${IMMICH_SB_PASSWORD}" | sudo tee -a /etc/davfs2/secrets > /dev/null
    sudo chmod 600 /etc/davfs2/secrets
    echo -e "${GREEN}✅ Added Immich Storage Box credentials to davfs2${NC}"
else
    echo -e "${YELLOW}⚠️  Immich Storage Box credentials already in davfs2 secrets${NC}"
    # Update password if it exists
    sudo sed -i "s|https://${IMMICH_SB_HOST} ${IMMICH_SB_USER} .*|https://${IMMICH_SB_HOST} ${IMMICH_SB_USER} ${IMMICH_SB_PASSWORD}|" /etc/davfs2/secrets
fi

# Ensure mount point exists
sudo mkdir -p "${IMMICH_SB_MOUNT}"
sudo chown root:root "${IMMICH_SB_MOUNT}"
sudo chmod 755 "${IMMICH_SB_MOUNT}"

# Add to fstab if not already present
if ! grep -q "${IMMICH_SB_MOUNT}" /etc/fstab; then
    echo "https://${IMMICH_SB_HOST} ${IMMICH_SB_MOUNT} davfs uid=1000,gid=1000,file_mode=0770,dir_mode=0770,noexec,nosuid,nodev,_netdev 0 0" | sudo tee -a /etc/fstab > /dev/null
    echo -e "${GREEN}✅ Added Immich Storage Box to /etc/fstab${NC}"
else
    echo -e "${YELLOW}⚠️  Immich Storage Box already in /etc/fstab${NC}"
fi

# Mount
if mountpoint -q "${IMMICH_SB_MOUNT}"; then
    echo -e "${YELLOW}⚠️  Immich Storage Box already mounted${NC}"
    sudo umount "${IMMICH_SB_MOUNT}" || true
fi

sudo mount "${IMMICH_SB_MOUNT}"
echo -e "${GREEN}✅ Immich Storage Box mounted at ${IMMICH_SB_MOUNT}${NC}"

##############################################################################
# VERIFY MOUNTS
##############################################################################

echo ""
echo -e "${YELLOW}🔍 Verifying mounts...${NC}"
echo ""

# Check main Storage Box
if mountpoint -q "${MAIN_SB_MOUNT}"; then
    echo -e "${GREEN}✅ Main Storage Box: ${MAIN_SB_MOUNT}${NC}"
    df -h | grep "${MAIN_SB_MOUNT}" || true
else
    echo -e "${RED}❌ Main Storage Box not mounted${NC}"
fi

# Check Immich Storage Box
if mountpoint -q "${IMMICH_SB_MOUNT}"; then
    echo -e "${GREEN}✅ Immich Storage Box: ${IMMICH_SB_MOUNT}${NC}"
    df -h | grep "${IMMICH_SB_MOUNT}" || true
else
    echo -e "${RED}❌ Immich Storage Box not mounted${NC}"
fi

echo ""
echo -e "${GREEN}✅ Storage Box mounting complete!${NC}"
echo ""
echo "To test access:"
echo "  ls -lah ${MAIN_SB_MOUNT}/"
echo "  ls -lah ${IMMICH_SB_MOUNT}/"

