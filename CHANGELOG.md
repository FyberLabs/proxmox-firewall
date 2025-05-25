# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Completed Tasks

#### Multi-Site Deployment

- Added comprehensive multi-site deployment documentation
- Created test suite for multi-site deployment
- Implemented test playbooks for:
  - Network connectivity
  - VPN connectivity
  - DNS resolution
  - Firewall rules
  - VM states
  - Cross-site connectivity
  - Backup verification

#### Firewall Configuration

- Removed environment use as much as possible
- Added environment reload when updated in README.md steps and master playbook
- Generalized site naming conventions
- Removed hardcoded device references in IPs, MACs, etc.
- Removed specific hardcoded devices
- Added example network device firewall rules instead of hard coding
- Implemented camera and IoT device network isolation
- Configured Home Assistant and IoT hub access rules

#### Terraform Refactoring

- Generated/include tfvars from site config
- Created template generation as part of ansible before terraform runs
- Set up tfstate backend in ansible before terraform
- Made VM template deployment selectable in site config

#### Ansible Refactoring

- Split ansible into deployment and local playbooks
- Included missing ansible vars from env in site generation
- Removed environment use where possible
- Added env reload when updated in README.md steps and master playbook
- Generalized site naming
- Removed hardcoded device references

#### Automation

- Created requirements script for python
- Added prereq script for Ubuntu packages
- Created script to find latest sources and hashes
- Implemented automatic updates for:
  - Ubuntu base for VMs
  - Omada
  - Zeek
  - Pangolin
  - Headscale
- Set up ansible for log/metric offloading/rotation/trim
- Added system recovery scripts
- Implemented VM template removal
- Created script to update/redeploy/reconfigure new VM versions
- Verified backup configuration with NFS and CIFS
- Reworked VM_software for package updates and notifications

#### Validation Tests

- Implemented Firewall State Validation:
  - OPNsense service status and configuration
  - Required packages verification
  - Firewall rules validation
  - NAT rules for WAN failover
  - DNS resolver configuration
  - DHCP server status and leases
  - VLAN configuration and tagging

- Implemented VM State Validation:
  - Proxmox VM states
  - VM resource verification
  - Cloud-init configuration
  - Network interface validation
  - VM template version testing
  - Backup configuration verification

- Implemented Network Connectivity Tests:
  - WAN connectivity (primary and failover)
  - VLAN routing and isolation
  - DNS resolution
  - DHCP server functionality
  - Firewall rule effectiveness
  - Tailscale subnet routing
  - SSH access to VMs
  - Web interface access
  - Service port validation
  - Cross-site routing

- Implemented Security Validation:
  - Firewall rules verification
  - VLAN isolation testing
  - Service access restrictions
  - WAN access controls
  - Failover security
  - Tailscale ACLs

#### Networking

- Implemented DHCP for all local VLANs
- Tested network transition from initial DHCP IPs to Management VLAN IPs
- Tested OPNsense Tailscale integration across sites

#### Security & Monitoring

- Implemented tailscale terraform for network connections
- Added support for netbird as an alternative to tailscale
- Added support for headscale self-hosting
- Implemented image download certificate/signature validation
