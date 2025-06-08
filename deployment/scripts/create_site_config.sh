#!/bin/bash
# create_site_config.sh - Script to configure multi-site Proxmox firewall deployments
#
# This script helps create and manage configuration for multiple firewall sites.
# It will:
# 1. Ask for site details (name, display name, network prefix, domain)
# 2. Create site-specific configuration files
# 3. Set up Terraform for each site
# 4. Generate appropriate .env file entries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
CONFIG_DIR="${SCRIPT_DIR}/config"
ANSIBLE_GROUP_VARS_DIR="${SCRIPT_DIR}/ansible/group_vars"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
TERRAFORM_STATES_DIR="${TERRAFORM_DIR}/states"

# Create necessary directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${TERRAFORM_STATES_DIR}"

# Color configuration
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}       Proxmox Firewall - Multi-Site Configuration          ${NC}"
echo -e "${BLUE}============================================================${NC}"

# Function to create site configuration
create_site_config() {
    echo -e "\n${GREEN}Creating new site configuration...${NC}"

    # Gather site information
    read -p "Site short name (lowercase, no spaces, e.g., primary): " site_name
    read -p "Site display name (e.g., Primary Home): " site_display_name
    read -p "Network prefix (e.g., 10.1): " network_prefix
    read -p "Domain name (e.g., primary.local): " domain
    read -p "Proxmox host IP or FQDN: " proxmox_host

    # Validate input
    if [[ -z "$site_name" || -z "$site_display_name" || -z "$network_prefix" || -z "$domain" || -z "$proxmox_host" ]]; then
        echo -e "${RED}Error: All fields are required${NC}"
        return 1
    fi

    # Create site config file (external configuration - NOT in Ansible)
    cat > "${CONFIG_DIR}/${site_name}.conf" <<EOL
# Site configuration for ${site_display_name}
# This file is loaded by Ansible but remains separate from the automation system
SITE_NAME="${site_name}"
SITE_DISPLAY_NAME="${site_display_name}"
NETWORK_PREFIX="${network_prefix}"
DOMAIN="${domain}"
PROXMOX_HOST="${proxmox_host}"

# Hardware defaults (can be overridden in site-specific YAML)
HARDWARE_CPU_TYPE="n100"
HARDWARE_CPU_CORES="4"
HARDWARE_MEMORY_TOTAL="8gb"
HARDWARE_STORAGE_TYPE="ssd"
HARDWARE_STORAGE_SIZE="128gb"

# Network defaults
WAN_INTERFACE="eth0"
WAN_BACKUP_INTERFACE="eth1"
LAN_INTERFACE="eth2"
CAMERA_INTERFACE="eth3"

# Service defaults
TIMEZONE="America/New_York"
TARGET_NODE="pve"
EOL

    # NO MORE TFVARS FILES! Terraform gets everything via environment variables

    # Create site directory for terraform state
    mkdir -p "${TERRAFORM_STATES_DIR}/${site_name}"

    # Create minimal Ansible group vars (references external config)
    cat > "${ANSIBLE_GROUP_VARS_DIR}/${site_name}.yml" <<EOL
---
# Ansible variables for ${site_display_name}
# Main configuration is in config/${site_name}.conf (external to Ansible)
# This file only contains Ansible-specific orchestration settings

site_config:
  # Basic site identification (loaded from external config)
  name: "${site_name}"
  display_name: "${site_display_name}"

  # External config file reference
  external_config_file: "{{ playbook_dir }}/../config/${site_name}.conf"

  # Ansible-specific settings
  proxmox:
    api_secret_env: "${site_name^^}_PROXMOX_API_SECRET"
    node_name: "pve"

  ssh:
    public_key_file: "{{ playbook_dir }}/../credentials/${site_name}_root.pub"
    private_key_file: "{{ lookup('env', 'ANSIBLE_SSH_PRIVATE_KEY_FILE') | default('~/.ssh/id_rsa') }}"

  tailscale:
    auth_key_env: "TAILSCALE_AUTH_KEY"

  # VM template defaults (can be overridden in external config)
  vm_templates:
    opnsense:
      enabled: true
      start_on_deploy: true
      cores: 4
      memory: 8192
      disk_size: "32G"
      network:
        - bridge: "vmbr0"  # WAN
        - bridge: "vmbr1"  # LAN
        - bridge: "vmbr2"  # Cameras
        - bridge: "vmbr3"  # WAN Backup
    tailscale:
      enabled: true
      start_on_deploy: true
      cores: 1
      memory: 1024
      disk_size: "8G"
      network:
        - bridge: "vmbr1"
          vlan: 50  # Management VLAN
    zeek:
      enabled: true
      start_on_deploy: false
      cores: 4
      memory: 8192
      disk_size: "100G"
      network:
        - bridge: "vmbr1"
          vlan: 50  # Management VLAN
        - bridge: "vmbr0"  # WAN monitoring
          promiscuous: true
    homeassistant:
      enabled: false
      start_on_deploy: false
      cores: 2
      memory: 4096
      disk_size: "32G"
      network:
        - bridge: "vmbr1"
          vlan: 10  # Main LAN
EOL

    # Add entries to the master hosts.yml if it exists
    if [ -f "${SCRIPT_DIR}/ansible/inventory/hosts.yml" ]; then
        # TODO: Update hosts.yml to include the new site
        echo -e "${YELLOW}You may need to manually update ansible/inventory/hosts.yml to include this site${NC}"
    fi

    # Update .env file with site-specific environment variables (for Terraform)
    if [ ! -f ".env" ]; then
        cat > .env <<EOL
# Multi-site Proxmox Firewall Configuration
# Generated by create_site_config.sh
#
# IMPORTANT: This file contains environment variables that Terraform reads directly
# No more .tfvars files - everything is passed via TF_VAR_* environment variables

# Global Terraform settings
TF_LOG="INFO"
TF_DATA_DIR=".terraform"

# Global service settings
ANSIBLE_SSH_PRIVATE_KEY_FILE="~/.ssh/id_rsa"
PROXMOX_STORAGE_POOL="local-lvm"
UBUNTU_TEMPLATE_ID="9001"
OPNSENSE_TEMPLATE_ID="9000"

# Tailscale (shared across all sites)
TAILSCALE_AUTH_KEY=""

# Site-specific configurations (loaded by Ansible, passed to Terraform)
EOL
    fi

    # Add site-specific environment variables for Terraform
    cat >> .env <<EOL

# ${site_display_name} Configuration
# Proxmox API credentials
${site_name^^}_PROXMOX_API_SECRET=""

# Site configuration (loaded from config/${site_name}.conf by Ansible)
${site_name^^}_NETWORK_PREFIX="${network_prefix}"
${site_name^^}_DOMAIN="${domain}"
${site_name^^}_PROXMOX_HOST="${proxmox_host}"

# SSH keys for this site
${site_name^^}_SSH_PUBLIC_KEY_FILE="credentials/${site_name}_root.pub"
${site_name^^}_SSH_PRIVATE_KEY_FILE="credentials/${site_name}_root"
EOL

    # Add environment variables to .env.example for documentation
    if [ -f "${SCRIPT_DIR}/env.example" ]; then
        cat >> "${SCRIPT_DIR}/env.example" <<EOL

# ${site_display_name} (${site_name}) Configuration
${site_name^^}_PROXMOX_HOST="${proxmox_host}"
${site_name^^}_NETWORK_PREFIX="${network_prefix}"
${site_name^^}_DOMAIN="${domain}"
${site_name^^}_PROXMOX_API_SECRET="your_proxmox_api_secret"
${site_name^^}_TAILSCALE_AUTH_KEY="your_tailscale_auth_key"
${site_name^^}_SSH_PUBLIC_KEY_FILE="credentials/${site_name}_root.pub"
${site_name^^}_SSH_PRIVATE_KEY_FILE="credentials/${site_name}_root"
# Device MAC addresses will be added when you run scripts/add_device.sh
# Each device will get its own environment variable with format:
# ${site_name^^}_DEVICE_NAME_MAC="xx:xx:xx:xx:xx:xx"
EOL
    fi

    echo -e "\n${GREEN}Site configuration for ${site_display_name} created successfully!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Update your .env file with the necessary credentials"
    echo -e "2. Add network devices using: ./scripts/add_device.sh"
    echo -e "3. Deploy the complete infrastructure with Ansible:"
    echo -e "   ansible-playbook ansible/master_playbook.yml --limit=${site_name}"
}

# Function to list existing sites
list_sites() {
    echo -e "\n${GREEN}Existing site configurations:${NC}"
    if [ -z "$(ls -A ${CONFIG_DIR} 2>/dev/null)" ]; then
        echo -e "${YELLOW}No sites configured yet.${NC}"
    else
        echo -e "${BLUE}Site Name\tDisplay Name\t\tNetwork\t\tDomain${NC}"
        echo -e "${BLUE}--------------------------------------------------------------${NC}"
        for site_file in "${CONFIG_DIR}"/*.conf; do
            source "${site_file}"
            printf "${GREEN}%-15s${NC}\t${GREEN}%-20s${NC}\t${GREEN}%-10s${NC}\t${GREEN}%s${NC}\n" \
                "${SITE_NAME}" "${SITE_DISPLAY_NAME}" "${NETWORK_PREFIX}" "${DOMAIN}"
        done
    fi
}

# Function to edit existing site
edit_site() {
    list_sites
    echo -e "\n${GREEN}Enter the short name of the site to edit:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.conf" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load existing values
    source "${CONFIG_DIR}/${site_name}.conf"

    echo -e "\n${GREEN}Editing site: ${SITE_DISPLAY_NAME}${NC}"
    echo -e "${YELLOW}Press Enter to keep current values${NC}"

    read -p "Site display name [${SITE_DISPLAY_NAME}]: " new_display_name
    read -p "Network prefix [${NETWORK_PREFIX}]: " new_network_prefix
    read -p "Domain name [${DOMAIN}]: " new_domain
    read -p "Proxmox host [${PROXMOX_HOST}]: " new_proxmox_host

    # Apply changes where provided
    site_display_name=${new_display_name:-$SITE_DISPLAY_NAME}
    network_prefix=${new_network_prefix:-$NETWORK_PREFIX}
    domain=${new_domain:-$DOMAIN}
    proxmox_host=${new_proxmox_host:-$PROXMOX_HOST}

    # Save changes to external config file
    cat > "${CONFIG_DIR}/${site_name}.conf" <<EOL
# Site configuration for ${site_display_name}
# This file is loaded by Ansible but remains separate from the automation system
SITE_NAME="${site_name}"
SITE_DISPLAY_NAME="${site_display_name}"
NETWORK_PREFIX="${network_prefix}"
DOMAIN="${domain}"
PROXMOX_HOST="${proxmox_host}"

# Hardware defaults (can be overridden in site-specific YAML)
HARDWARE_CPU_TYPE="n100"
HARDWARE_CPU_CORES="4"
HARDWARE_MEMORY_TOTAL="8gb"
HARDWARE_STORAGE_TYPE="ssd"
HARDWARE_STORAGE_SIZE="128gb"

# Network defaults
WAN_INTERFACE="eth0"
WAN_BACKUP_INTERFACE="eth1"
LAN_INTERFACE="eth2"
CAMERA_INTERFACE="eth3"

# Service defaults
TIMEZONE="America/New_York"
TARGET_NODE="pve"
EOL

    # NO MORE TFVARS FILES! Update .env instead
    # Update environment variables in .env file
    if [ -f ".env" ]; then
        # Update existing entries or add new ones
        sed -i "/^${site_name^^}_NETWORK_PREFIX=/d" .env
        sed -i "/^${site_name^^}_DOMAIN=/d" .env
        sed -i "/^${site_name^^}_PROXMOX_HOST=/d" .env

        cat >> .env <<EOL

# Updated ${site_display_name} Configuration
${site_name^^}_NETWORK_PREFIX="${network_prefix}"
${site_name^^}_DOMAIN="${domain}"
${site_name^^}_PROXMOX_HOST="${proxmox_host}"
EOL
    fi

    # Update minimal Ansible group vars (references external config)
    cat > "${ANSIBLE_GROUP_VARS_DIR}/${site_name}.yml" <<EOL
---
# Ansible variables for ${site_display_name}
# Main configuration is in config/${site_name}.conf (external to Ansible)
# This file only contains Ansible-specific orchestration settings

site_config:
  # Basic site identification (loaded from external config)
  name: "${site_name}"
  display_name: "${site_display_name}"

  # External config file reference
  external_config_file: "{{ playbook_dir }}/../config/${site_name}.conf"

  # Ansible-specific settings
  proxmox:
    api_secret_env: "${site_name^^}_PROXMOX_API_SECRET"
    node_name: "pve"

  ssh:
    public_key_file: "{{ playbook_dir }}/../credentials/${site_name}_root.pub"
    private_key_file: "{{ lookup('env', 'ANSIBLE_SSH_PRIVATE_KEY_FILE') | default('~/.ssh/id_rsa') }}"

  tailscale:
    auth_key_env: "TAILSCALE_AUTH_KEY"
EOL

    echo -e "\n${GREEN}Site '${site_name}' updated successfully!${NC}"
}

# Function to generate deployment commands for a site
deploy_site() {
    list_sites
    echo -e "\n${GREEN}Enter the short name of the site to deploy:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.conf" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load site config
    source "${CONFIG_DIR}/${site_name}.conf"

    echo -e "\n${GREEN}Deployment commands for ${SITE_DISPLAY_NAME}:${NC}"
    echo -e "${YELLOW}Make sure your .env file is updated with credentials for this site${NC}"
    echo
    echo -e "${BLUE}# Configure devices for this site (if not done already)${NC}"
    echo -e "./scripts/add_device.sh"
    echo
    echo -e "${BLUE}# Deploy the complete infrastructure with Ansible${NC}"
    echo -e "ansible-playbook ansible/master_playbook.yml --limit=${site_name}"
    echo
    echo -e "${BLUE}# For network-specific updates only${NC}"
    echo -e "ansible-playbook ansible/master_playbook.yml --limit=${site_name} --tags=network,dhcp"
    echo
}

# Main menu
while true; do
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${GREEN}Options:${NC}"
    echo -e "  1. Create new site configuration"
    echo -e "  2. List existing sites"
    echo -e "  3. Edit existing site"
    echo -e "  4. Generate deployment commands for a site"
    echo -e "  q. Quit"
    echo -e "${BLUE}============================================================${NC}"
    read -p "Select an option: " option

    case $option in
        1) create_site_config ;;
        2) list_sites ;;
        3) edit_site ;;
        4) deploy_site ;;
        q|Q) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
