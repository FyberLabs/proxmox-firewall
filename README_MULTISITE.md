# Multi-Site Deployment for Proxmox Firewall

This document explains how to use the multi-site deployment features of the Proxmox Firewall project.

## Overview

> **See the main [README](README.md) for a high-level overview of multi-site management and project structure. The recommended approach is to use the template repo with proxmox-firewall as a submodule.**

The multi-site deployment system allows you to:

1. Configure and manage multiple firewall sites from a single codebase
2. Keep site-specific configuration separate from common code
3. Deploy and manage sites independently
4. Add new sites without modifying existing deployments

Each site has its own:

- Network prefix (e.g., 10.1.x.x for primary, 10.2.x.x for secondary)
- Domain name
- Proxmox host
- Terraform state
- Device-specific configurations

## Quick Start

The easiest way to get started is to use the `vendor/proxmox-firewall/deployment/scripts/create_site_config.sh` script:

```bash
./vendor/proxmox-firewall/deployment/scripts/create_site_config.sh
```

This interactive script will:

1. Ask you questions about your site
2. Create all necessary configuration files
3. Set up the directory structure
4. Provide commands for deployment

## Manual Configuration

If you prefer to configure sites manually:

### 1. Create site configuration files

For each site, create a file in `config/site_name.conf`:

```bash
SITE_NAME="primary"
SITE_DISPLAY_NAME="Primary Home"
NETWORK_PREFIX="10.1"
DOMAIN="primary.local"
PROXMOX_HOST="10.1.50.1"
```

### 2. Create Terraform variable files

For each site, create a file in `terraform/site_name.tfvars`:

```hcl
# Terraform variables for Primary Home
proxmox_host = "10.1.50.1"

# Site configuration
site_name = "primary"
site_display_name = "Primary Home"
network_prefix = "10.1"
domain = "primary.local"

# Common configuration
timezone = "America/New_York"
target_node = "pve"
```

### 3. Create Ansible group variables

For each site, create a file in `ansible/group_vars/site_name.yml`:

```yaml
---
# Site-specific variables for Primary Home
site_config:
  name: "primary"
  display_name: "Primary Home"
  network_prefix: "10.1"
  domain: "primary.local"
```

### 4. Update Ansible inventory

Add each site to your `ansible/inventory/hosts.yml`:

```yaml
all:
  children:
    firewalls:
      children:
        primary:
          hosts:
            primary_firewall:
              ansible_host: "10.1.50.1"
              ansible_user: root
        
        secondary:
          hosts:
            secondary_firewall:
              ansible_host: "10.2.50.1"
              ansible_user: root
```

## Deployment Process

### First-time setup for a site

1. Initialize Terraform with the site-specific state path:

```bash
cd terraform
terraform init -backend-config="path=states/primary/terraform.tfstate"
```

2. Apply Terraform with the site-specific variables:

```bash
terraform apply -var-file="primary.tfvars"
```

3. Run Ansible for the site:

```bash
cd ..
ansible-playbook ansible/master_playbook.yml --limit=primary
```

### Adding a new site

1. Use the `scripts/create_site_config.sh` script to set up the new site
2. Update your `.env` file with any site-specific credentials
3. Follow the deployment process above for the new site

### Updating existing sites

When you make improvements to the codebase that should apply to all sites:

1. Test changes on one site first
2. After verifying, deploy to other sites as needed
3. Use the same Terraform and Ansible commands, just changing the site name

## Environment Variables

For each site, add these to your `.env` file:

```bash
# Primary Home (primary) Configuration
PRIMARY_PROXMOX_HOST="10.1.50.1"
PRIMARY_NETWORK_PREFIX="10.1"
PRIMARY_DOMAIN="primary.local"
PRIMARY_HOME_ASSISTANT_MAC="00:11:22:33:44:55"
PRIMARY_NAS_MAC="aa:bb:cc:dd:ee:ff"
PRIMARY_NVR_MAC="11:22:33:44:55:66"
PRIMARY_OMADA_MAC="aa:bb:cc:dd:ee:ff"

# Secondary Home (secondary) Configuration
SECONDARY_PROXMOX_HOST="10.2.50.1"
# Add additional variables as needed
```

## Managing MAC Addresses for DHCP

The system can automatically configure static DHCP mappings for known devices. For each device you want to have a static IP:

1. Add the MAC address to your `.env` file with the format: `SITE_DEVICE_MAC`
2. The system will automatically map to the appropriate IP based on the VLAN and device configuration

## Tips and Best Practices

1. **Consistent network design**: Use the same VLAN structure across all sites
2. **Site naming**: Choose short, descriptive names for your sites
3. **Testing changes**: Test significant changes on one site before deploying to all
4. **Backing up state**: Regularly back up your Terraform state files
5. **Git branches**: Use separate branches for site-specific experimental changes

## Troubleshooting

If you encounter issues:

1. **Terraform state mismatch**: If Terraform can't find resources it created, check that you're using the correct state file path
2. **Missing environment variables**: Ensure all required variables exist in your `.env` file
3. **Ansible inventory issues**: Verify your hosts.yml file has the correct site groups

## Extending the System

To add support for additional types of devices or VLANs:

1. Update `ansible/group_vars/all.yml` to include the new VLAN or device types
2. Ensure any templates or tasks that configure these devices are updated
3. Redeploy to your sites
