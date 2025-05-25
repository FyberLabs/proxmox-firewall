# Proxmox Local Scripts

This directory contains the scripts and configurations that will be deployed to /opt/proxmox-firewall/ on the Proxmox server.

## Contents

- ansible/: Operational Ansible playbooks and roles
- terraform/: Local Terraform configurations and state
- scripts/: Maintenance and scheduling scripts
- config/: Site and device configurations

## Setup

1. Copy this directory to /opt/proxmox-firewall/
2. Configure .env file with site and device IDs
3. Run the loader script to begin operations
