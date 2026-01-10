#!/bin/bash
# Fix Tailscale files for jellyfin-arr service
# Moves files from config/tailscale/ to config/tailscale/jellyfin-arr/
# and fixes ownership/permissions

set -e

HOMELAB_DIR="/opt/homelab"
TAILSCALE_DIR="${HOMELAB_DIR}/config/tailscale"
JELLYFIN_ARR_DIR="${TAILSCALE_DIR}/jellyfin-arr"

echo "Fixing Tailscale files for jellyfin-arr..."

# Ensure jellyfin-arr directory exists
sudo mkdir -p "${JELLYFIN_ARR_DIR}"

# Files to move from config/tailscale/ to config/tailscale/jellyfin-arr/
FILES_TO_MOVE=(
    "certs"
    "files"
    "derpmap.cached.json"
    "tailscaled.log1.txt"
    "tailscaled.log2.txt"
    "tailscaled.log.conf"
    "tailscaled.state"
)

# Move files that don't belong to other services
for file in "${FILES_TO_MOVE[@]}"; do
    if [ -e "${TAILSCALE_DIR}/${file}" ]; then
        # Check if file already exists in jellyfin-arr
        if [ -e "${JELLYFIN_ARR_DIR}/${file}" ]; then
            echo "  ${file} already exists in jellyfin-arr, removing orphaned file from parent directory..."
            sudo rm -rf "${TAILSCALE_DIR}/${file}"
        else
            echo "  Moving ${file} to jellyfin-arr..."
            sudo mv "${TAILSCALE_DIR}/${file}" "${JELLYFIN_ARR_DIR}/${file}"
        fi
    fi
done

# Fix ownership - Tailscale container runs as root, so files should be root:root
# But we'll use deploy:deploy to match other Tailscale services
echo "Fixing ownership in jellyfin-arr directory..."
sudo chown -R deploy:deploy "${JELLYFIN_ARR_DIR}"

# Ensure proper permissions
sudo chmod 700 "${JELLYFIN_ARR_DIR}"
sudo find "${JELLYFIN_ARR_DIR}" -type f -exec chmod 600 {} \;
sudo find "${JELLYFIN_ARR_DIR}" -type d -exec chmod 700 {} \;

# Special handling for ts-jellyfin.json (should be readable)
if [ -f "${JELLYFIN_ARR_DIR}/ts-jellyfin.json" ]; then
    sudo chmod 600 "${JELLYFIN_ARR_DIR}/ts-jellyfin.json"
fi

echo "Done! Files organized in ${JELLYFIN_ARR_DIR}:"
sudo ls -la "${JELLYFIN_ARR_DIR}"
