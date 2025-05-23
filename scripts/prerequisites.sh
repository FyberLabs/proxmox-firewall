#!/bin/bash
# prerequisites.sh - Install required packages and Python dependencies
#
# This script installs all necessary packages and Python modules
# required for the Proxmox Firewall deployment system.

set -e

# Color configuration
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}       Proxmox Firewall - Prerequisites Installation        ${NC}"
echo -e "${BLUE}============================================================${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Python package
install_python_package() {
    echo -e "${YELLOW}Installing Python package: $1${NC}"
    pip3 install "$1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Update package lists
echo -e "\n${GREEN}Updating package lists...${NC}"
# Install required tools (if not already present)
# Add the Proxmox VE repository as root:
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list

# Import the Proxmox VE signing key:
sudo wget http://download.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

sudo apt-get update

# Install required system packages
echo -e "\n${GREEN}Installing required system packages...${NC}"
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    pipx \
    curl \
    wget \
    jq \
    yq \
    xorriso \
    whois \
    proxmox-auto-install-assistant


# Install Python packages
echo -e "\n${GREEN}Installing required Python packages...${NC}"
##NONE

# Create necessary directories
echo -e "\n${GREEN}Creating necessary directories...${NC}"
mkdir -p config
mkdir -p credentials
mkdir -p devices
mkdir -p templates/devices/examples
mkdir -p ansible/group_vars
mkdir -p terraform/states

# Set up Python virtual environment
echo -e "\n${GREEN}Setting up Python virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# Install additional Python packages in virtual environment
pipx ensurepath
pipx install --include-deps ansible
pipx install ansible-dev-tools ansible-lint httpx proxmoxer python-dotenv

ansible-galaxy collection install -r ansible/collections/requirements.yml

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "\n${GREEN}Creating .env file...${NC}"
    cat > .env <<EOL
# Required for all sites
ANSIBLE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_rsa

# Add site-specific variables here after running create_site_config.sh
EOL
fi

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "\n${YELLOW}No SSH key found. Generating new SSH key...${NC}"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo -e "${GREEN}SSH key generated. Public key:${NC}"
    cat ~/.ssh/id_rsa.pub
fi

echo -e "\n${GREEN}Prerequisites installation completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Run ./scripts/validate_images.sh to download latest images"
echo -e "2. Run ./scripts/create_proxmox_iso.sh to create custom ISO"
echo -e "3. Run ./scripts/create_site_config.sh to configure your sites"
