#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CREDS_DIR="credentials"
mkdir -p "$CREDS_DIR"

echo -e "${YELLOW}==================================${NC}"
echo -e "${YELLOW}CREDENTIAL RETRIEVAL TOOL${NC}"
echo -e "${YELLOW}==================================${NC}"
echo

# Function to process credentials for a site
process_site_credentials() {
    local site_name=$1
    local site_prefix=$(echo "$site_name" | tr '[:lower:]' '[:upper:]')

    # Check for site-specific API token
    local api_token=$(cat "$CREDS_DIR/${site_name}-proxmox_api_token.txt" 2>/dev/null || echo "Not found")

    echo -e "${GREEN}${site_prefix} Proxmox API Token:${NC} $api_token"

    # Update .env file with site-specific credentials
    if [ -f ".env" ]; then
        # Update API token
        if [ "$api_token" != "Not found" ]; then
            local env_var="PROXMOX_API_SECRET_${site_prefix}_PROXMOX"
            grep -q "$env_var=" .env || echo "$env_var=\"$api_token\"" >> .env
            sed -i "s/^$env_var=.*/$env_var=\"$api_token\"/" .env
        fi

        # Update other site-specific variables if they exist
        for var in "NETWORK_PREFIX" "PROXMOX_IP" "LAN_INTERFACE" "WAN_INTERFACE" "CAMERA_INTERFACE" "STARLINK_INTERFACE"; do
            local env_var="${site_prefix}_${var}"
            if [ -f "$CREDS_DIR/${site_name}_${var,,}.txt" ]; then
                local value=$(cat "$CREDS_DIR/${site_name}_${var,,}.txt")
                grep -q "$env_var=" .env || echo "$env_var=\"$value\"" >> .env
                sed -i "s/^$env_var=.*/$env_var=\"$value\"/" .env
            fi
        done
    fi
}

# Check if site_config.json exists
if [ ! -f "site_config.json" ]; then
    echo -e "${RED}Error: site_config.json not found${NC}"
    echo "Please create a site configuration file first"
    exit 1
fi

# Extract site names from site_config.json
SITES=$(jq -r '.sites[].name' site_config.json 2>/dev/null)

if [ -z "$SITES" ]; then
    echo -e "${RED}Error: No sites found in site_config.json${NC}"
    exit 1
fi

# Process each site
for site in $SITES; do
    echo
    echo -e "${YELLOW}Processing credentials for site: ${site}${NC}"
    process_site_credentials "$site"
done

# Create or update .env file with common variables if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}No .env file found. Creating one...${NC}"
    cat > .env <<EOF
# Common Settings
ROOT_PASSWORD="your_secure_password"
ADMIN_EMAIL="admin@example.com"
TAILSCALE_AUTH_KEY="your_tailscale_auth_key"

# Backup Settings
ENABLE_VM_BACKUPS="true"
BACKUP_NAS_ADDRESS="your_nas_address"
BACKUP_NAS_SHARE="your_nas_share"
BACKUP_NAS_USERNAME="your_nas_username"
BACKUP_NAS_PASSWORD="your_nas_password"
BACKUP_NAS_PROTOCOL="nfs"
BACKUP_SCHEDULE="0 2 * * 0"
BACKUP_RETENTION="3"
BACKUP_COMPRESS="1"
BACKUP_MODE="snapshot"

# Site-specific variables will be added above
EOF
    echo -e "${GREEN}.env file created with template${NC}"
fi

echo
echo -e "${YELLOW}Please ensure you update any missing credentials in the .env file${NC}"
echo -e "${YELLOW}Site-specific credentials have been updated based on available files${NC}"
