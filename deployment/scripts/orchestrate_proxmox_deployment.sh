#!/bin/bash

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Function to print status messages
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "\e[34mℹ️  $message\e[0m" ;;
        "success") echo -e "\e[32m✅ $message\e[0m" ;;
        "error") echo -e "\e[31m❌ $message\e[0m" ;;
        "warning") echo -e "\e[33m⚠️  $message\e[0m" ;;
    esac
}

# Function to validate required environment variables
validate_env() {
    local required_vars=(
        "PROXMOX_ISO_URL"
        "PROXMOX_ROOT_PASSWORD"
        "PROXMOX_ADMIN_EMAIL"
        "PROXMOX_FQDN"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            print_status "error" "Required environment variable $var is not set"
            exit 1
        fi
    done
}

# Function to create site configuration
create_site_config() {
    local site_name=$1
    print_status "info" "Creating configuration for site: $site_name"

    # Run create_site_config.sh with the site name
    ./scripts/create_site_config.sh "$site_name"

    if [ $? -eq 0 ]; then
        print_status "success" "Site configuration created successfully"
    else
        print_status "error" "Failed to create site configuration"
        exit 1
    fi
}

# Function to create Proxmox ISO
create_proxmox_iso() {
    local site_name=$1
    print_status "info" "Creating Proxmox ISO for site: $site_name"

    # Run ansible playbook to create ISO
    ansible-playbook ansible/playbooks/create_proxmox_iso.yml \
        -e "site_name=$site_name" \
        -e "proxmox_iso_url=$PROXMOX_ISO_URL"

    if [ $? -eq 0 ]; then
        print_status "success" "Proxmox ISO created successfully"
    else
        print_status "error" "Failed to create Proxmox ISO"
        exit 1
    fi
}

# Main function
main() {
    local site_name=$1

    # Validate environment variables
    validate_env

    # Create site configuration
    create_site_config "$site_name"

    # Create Proxmox ISO
    create_proxmox_iso "$site_name"

    print_status "info" "Deployment preparation completed for site: $site_name"
    print_status "info" "Next steps:"
    print_status "info" "1. Install Proxmox using the generated ISO at output/${site_name}_proxmox.iso"
    print_status "info" "2. After installation, run: ./scripts/orchestrate_proxmox_deployment.sh $site_name --apply-config"
}

# Check if site name is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <site_name>"
    exit 1
fi

site_name=$1

main "$site_name"

