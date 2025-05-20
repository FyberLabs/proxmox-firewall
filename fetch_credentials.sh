#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CREDS_DIR="credentials"
mkdir -p "$CREDS_DIR"

echo -e "${YELLOW}==================================${NC}"
echo -e "${YELLOW}CREDENTIAL RETRIEVAL TOOL${NC}"
echo -e "${YELLOW}==================================${NC}"
echo

# Check for credentials files
TENNESSEE_API=$(cat "$CREDS_DIR/tn-proxmox_api_token.txt" 2>/dev/null || echo "Not found")
PRIMARY_API=$(cat "$CREDS_DIR/ph-proxmox_api_token.txt" 2>/dev/null || echo "Not found")

# Display terraform API tokens
echo -e "${GREEN}Tennessee Proxmox API Token:${NC} $TENNESSEE_API"
echo -e "${GREEN}Primary Home Proxmox API Token:${NC} $PRIMARY_API"
echo

# Check and update .env file
if [ -f ".env" ]; then
    echo -e "${GREEN}Updating .env file with credentials...${NC}"
    
    # Update Tennessee API token
    if [ "$TENNESSEE_API" != "Not found" ]; then
        grep -q "PROXMOX_API_SECRET_TN_PROXMOX=" .env || echo "PROXMOX_API_SECRET_TN_PROXMOX=\"$TENNESSEE_API\"" >> .env
        sed -i "s/^PROXMOX_API_SECRET_TN_PROXMOX=.*/PROXMOX_API_SECRET_TN_PROXMOX=\"$TENNESSEE_API\"/" .env
    fi
    
    # Update Primary Home API token
    if [ "$PRIMARY_API" != "Not found" ]; then
        grep -q "PROXMOX_API_SECRET_PH_PROXMOX=" .env || echo "PROXMOX_API_SECRET_PH_PROXMOX=\"$PRIMARY_API\"" >> .env
        sed -i "s/^PROXMOX_API_SECRET_PH_PROXMOX=.*/PROXMOX_API_SECRET_PH_PROXMOX=\"$PRIMARY_API\"/" .env
    fi
    
    echo -e "${GREEN}Credentials updated in .env file${NC}"
else
    echo -e "${YELLOW}No .env file found. Creating one...${NC}"
    cat > .env <<EOF
# Proxmox Secrets
ROOT_PASSWORD="your_secure_password"
ADMIN_EMAIL="admin@example.com"
PROXMOX_API_SECRET_TN_PROXMOX="$TENNESSEE_API"
PROXMOX_API_SECRET_PH_PROXMOX="$PRIMARY_API"
TAILSCALE_AUTH_KEY="your_tailscale_auth_key"
EOF
    echo -e "${GREEN}.env file created with credentials${NC}"
fi

echo
echo -e "${YELLOW}Please ensure you update any missing credentials in the .env file${NC}"
