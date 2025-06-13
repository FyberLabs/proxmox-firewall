#!/bin/bash
# Refactored: Use PROXMOX_FW_CONFIG_ROOT for config path, supporting submodule usage.
# Set via environment, or auto-detect below.

# Auto-detect config root
if [ -z "$PROXMOX_FW_CONFIG_ROOT" ]; then
  if [ -d "vendor/proxmox-firewall/config" ]; then
    export PROXMOX_FW_CONFIG_ROOT="vendor/proxmox-firewall/config"
  elif [ -d "./config" ]; then
    export PROXMOX_FW_CONFIG_ROOT="./config"
  else
    echo "ERROR: Could not find config root directory." >&2
    exit 1
  fi
fi

# Use $PROXMOX_FW_CONFIG_ROOT in all config path references below

# create_site_config.sh - Script to configure multi-site Proxmox firewall deployments
#
# This script helps create and manage configuration for multiple firewall sites.
# It will:
# 1. Ask for site details (name, display name, network prefix, domain)
# 2. Create site-specific configuration files
# 3. Set up Terraform for each site
# 4. Generate appropriate .env file entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/config/sites"
ANSIBLE_GROUP_VARS_DIR="${SCRIPT_DIR}/ansible/group_vars"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
TERRAFORM_STATES_DIR="${TERRAFORM_DIR}/states"

# Create necessary directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${TERRAFORM_STATES_DIR}"
mkdir -p "${ANSIBLE_GROUP_VARS_DIR}"

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
    echo -e "${GREEN}Creating new site configuration${NC}"
    echo -e "${YELLOW}This will create a single YAML file that contains all site configuration${NC}"
    echo

    # Get basic site information
    read -p "Site short name (lowercase, no spaces): " site_name
    read -p "Site display name: " site_display_name
    read -p "Network prefix (e.g., 192.168): " network_prefix
    read -p "Domain name: " domain
    read -p "Proxmox host IP/hostname: " proxmox_host

    # Validate inputs
    if [[ ! "$site_name" =~ ^[a-z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Site name must be lowercase letters, numbers, underscores, or hyphens only${NC}"
        return 1
    fi

    if [ -f "${CONFIG_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' already exists${NC}"
        return 1
    fi

    # Create the comprehensive site configuration YAML
    cat > "${CONFIG_DIR}/${site_name}.yml" <<EOL
# Site Configuration: ${site_display_name}
# This is the single source of truth for this site's configuration
# Ansible reads this file directly - no duplicate configs needed

site:
  name: "${site_name}"
  network_prefix: "${network_prefix}"
  domain: "${domain}"
  display_name: "${site_display_name}"

  # Hardware Configuration
  hardware:
    cpu:
      type: "n100"
      cores: 4
      threads: 4

    memory:
      total: "8gb"
      vm_allocation:
        opnsense: "4gb"
        tailscale: "1gb"
        zeek: "2gb"
        homeassistant: "1gb"

    storage:
      type: "ssd"
      size: "128gb"
      allocation:
        system: "20gb"
        vms: "80gb"
        backups: "28gb"

    network:
      interfaces:
        - name: "eth0"
          type: "2.5gbe"
          role: "wan"
          vlan: null
        - name: "eth1"
          type: "2.5gbe"
          role: "wan_backup"
          vlan: null
        - name: "eth2"
          type: "10gbe"
          role: "lan"
          vlan: [10, 30, 40, 50]
        - name: "eth3"
          type: "10gbe"
          role: "cameras"
          vlan: [20]

      vlans:
        - id: 10
          name: "main"
          subnet: "${network_prefix}.10.0/24"
          dhcp: true
          gateway: "${network_prefix}.10.1"
        - id: 20
          name: "cameras"
          subnet: "${network_prefix}.20.0/24"
          dhcp: true
          gateway: "${network_prefix}.20.1"
        - id: 30
          name: "iot"
          subnet: "${network_prefix}.30.0/24"
          dhcp: true
          gateway: "${network_prefix}.30.1"
        - id: 40
          name: "guest"
          subnet: "${network_prefix}.40.0/24"
          dhcp: true
          gateway: "${network_prefix}.40.1"
        - id: 50
          name: "management"
          subnet: "${network_prefix}.50.0/24"
          dhcp: true
          gateway: "${network_prefix}.50.1"

      bridges:
        - name: "vmbr0"
          interface: "eth0"
          description: "WAN Bridge"
        - name: "vmbr1"
          interface: "eth2"
          description: "LAN Bridge"
          vlans: [10, 30, 40, 50]
        - name: "vmbr2"
          interface: "eth3"
          description: "Camera Bridge"
          vlans: [20]
        - name: "vmbr3"
          interface: "eth1"
          description: "WAN Backup Bridge"

  # Proxmox Configuration
  proxmox:
    host: "${proxmox_host}"
    node_name: "pve"
    storage_pool: "local-lvm"
    template_storage: "local"

  # VM Templates
  vm_templates:
    opnsense:
      enabled: true
      template_id: 9000
      cores: 4
      memory: 4096
      disk_size: "32G"
      start_on_deploy: true
      network:
        - bridge: "vmbr0"
          model: "virtio"
        - bridge: "vmbr1"
          model: "virtio"
        - bridge: "vmbr2"
          model: "virtio"
        - bridge: "vmbr3"
          model: "virtio"

    tailscale:
      enabled: true
      template_id: 9001
      cores: 1
      memory: 1024
      disk_size: "8G"
      start_on_deploy: true
      network:
        - bridge: "vmbr1"
          model: "virtio"
          vlan: 50

    zeek:
      enabled: true
      template_id: 9001
      cores: 2
      memory: 2048
      disk_size: "50G"
      start_on_deploy: false
      network:
        - bridge: "vmbr1"
          model: "virtio"
          vlan: 50
        - bridge: "vmbr0"
          model: "virtio"
          promiscuous: true

    homeassistant:
      enabled: false
      template_id: 9001
      cores: 2
      memory: 1024
      disk_size: "16G"
      start_on_deploy: false
      network:
        - bridge: "vmbr1"
          model: "virtio"
          vlan: 10

  # Security Configuration
  security:
    firewall:
      default_policy: "deny"
      rules:
        - name: "Allow LAN to WAN"
          source: "${network_prefix}.10.0/24"
          destination: "any"
          action: "allow"
        - name: "Block IoT to LAN"
          source: "${network_prefix}.30.0/24"
          destination: "${network_prefix}.10.0/24"
          action: "deny"
        - name: "Allow Guest Internet Only"
          source: "${network_prefix}.40.0/24"
          destination: "!${network_prefix}.0.0/16"
          action: "allow"

    suricata:
      enabled: true
      interfaces: ["WAN", "WAN_BACKUP"]
      ruleset: "emerging-threats"

  # Monitoring Configuration
  monitoring:
    enabled: true
    retention_days: 30
    alerts:
      email: "admin@${domain}"
      webhook: null

  # Backup Configuration
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 7
    destination: "local"

  # Credentials (environment variable names - actual values in .env)
  credentials:
    proxmox_api_secret: "${site_name^^}_PROXMOX_API_SECRET"
    tailscale_auth_key: "TAILSCALE_AUTH_KEY"
    ssh_public_key_file: "credentials/${site_name}_root.pub"
    ssh_private_key_file: "credentials/${site_name}_root"
EOL

    # Create minimal Ansible group_vars file
    echo -e "${GREEN}Creating minimal Ansible group_vars file...${NC}"
    cat > "${ANSIBLE_GROUP_VARS_DIR}/${site_name}.yml" <<EOL
---
# Minimal Group Variables for ${site_name}
# This file only contains the path to the main site configuration
# All site configuration is read directly from config/sites/${site_name}.yml

# Path to the main site configuration file
site_config_file: "{{ playbook_dir }}/../../config/sites/${site_name}.yml"
EOL

    # Create site directory for terraform state
    mkdir -p "${TERRAFORM_STATES_DIR}/${site_name}"

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

# Site configuration (loaded from config/sites/${site_name}.yml by Ansible)
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
    echo -e "${YELLOW}Configuration files created:${NC}"
    echo -e "  - Site config: ${CONFIG_DIR}/${site_name}.yml"
    echo -e "  - Ansible group_vars: ${ANSIBLE_GROUP_VARS_DIR}/${site_name}.yml (minimal)"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Update ${PROJECT_ROOT}/.env with your Proxmox API secret"
    echo -e "2. Generate SSH keys: ssh-keygen -t rsa -f credentials/${site_name}_root"
    echo -e "3. Deploy with: ansible-playbook deployment/ansible/master_playbook.yml --limit=${site_name}"
}

# Function to list existing sites
list_sites() {
    echo -e "\n${GREEN}Existing site configurations:${NC}"
    if [ -z "$(ls -A ${CONFIG_DIR}/*.yml 2>/dev/null)" ]; then
        echo -e "${YELLOW}No sites configured yet.${NC}"
    else
        echo -e "${BLUE}Site Name\tDisplay Name\t\tNetwork\t\tDomain${NC}"
        echo -e "${BLUE}--------------------------------------------------------------${NC}"
        for site_file in "${CONFIG_DIR}"/*.yml; do
            if [ -f "$site_file" ]; then
                # Extract values from YAML using basic parsing
                site_name=$(basename "$site_file" .yml)
                display_name=$(grep "display_name:" "$site_file" | sed 's/.*display_name: *"\([^"]*\)".*/\1/')
                network_prefix=$(grep "network_prefix:" "$site_file" | sed 's/.*network_prefix: *"\([^"]*\)".*/\1/')
                domain=$(grep "domain:" "$site_file" | sed 's/.*domain: *"\([^"]*\)".*/\1/')

                printf "${GREEN}%-15s${NC}\t${GREEN}%-20s${NC}\t${GREEN}%-10s${NC}\t${GREEN}%s${NC}\n" \
                    "${site_name}" "${display_name}" "${network_prefix}" "${domain}"
            fi
        done
    fi
}

# Function to edit existing site
edit_site() {
    list_sites
    echo -e "\n${GREEN}Enter the site name of the site to edit:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Opening ${site_name}.yml in your default editor...${NC}"
    echo -e "${YELLOW}Edit the YAML file directly - it's the single source of truth${NC}"

    # Use the user's preferred editor
    ${EDITOR:-nano} "${CONFIG_DIR}/${site_name}.yml"

    echo -e "\n${GREEN}Site '${site_name}' configuration updated!${NC}"
}

# Function to validate site configuration
validate_site() {
    list_sites
    echo -e "\n${GREEN}Enter the site name of the site to validate:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Validating ${site_name}.yml...${NC}"

    # Basic YAML syntax check
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import yaml
import sys
try:
    with open('${CONFIG_DIR}/${site_name}.yml', 'r') as f:
        yaml.safe_load(f)
    print('✓ YAML syntax is valid')
except yaml.YAMLError as e:
    print(f'✗ YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'✗ Error reading file: {e}')
    sys.exit(1)
"
    else
        echo -e "${YELLOW}Python3 not available - skipping YAML validation${NC}"
    fi

    echo -e "${GREEN}Configuration file: ${CONFIG_DIR}/${site_name}.yml${NC}"
}

# Function to generate deployment commands for a site
deploy_site() {
    list_sites
    echo -e "\n${GREEN}Enter the site name of the site to deploy:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Deployment commands for ${site_name}:${NC}"
    echo -e "${YELLOW}Make sure your .env file has the required credentials${NC}"
    echo
    echo -e "${BLUE}# Deploy the complete infrastructure${NC}"
    echo -e "cd ${PROJECT_ROOT}"
    echo -e "ansible-playbook deployment/ansible/master_playbook.yml --limit=${site_name}"
    echo
    echo -e "${BLUE}# For specific components only${NC}"
    echo -e "ansible-playbook deployment/ansible/master_playbook.yml --limit=${site_name} --tags=network"
    echo -e "ansible-playbook deployment/ansible/master_playbook.yml --limit=${site_name} --tags=vms"
    echo
}

# Main menu
while true; do
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${GREEN}Proxmox Firewall Site Configuration Manager${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "  1. Create new site configuration"
    echo -e "  2. List existing sites"
    echo -e "  3. Edit existing site"
    echo -e "  4. Validate site configuration"
    echo -e "  5. Generate deployment commands"
    echo -e "  q. Quit"
    echo -e "${BLUE}============================================================${NC}"
    read -p "Select an option: " option

    case $option in
        1) create_site_config ;;
        2) list_sites ;;
        3) edit_site ;;
        4) validate_site ;;
        5) deploy_site ;;
        q|Q) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
