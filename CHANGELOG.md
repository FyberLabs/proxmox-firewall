# Changelog

All notable changes to this project will be documented in this file.

## [0.44.0] - TBD

### Added

#### Local Management System
- **Automated Proxmox Self-Management**: Complete system for Proxmox servers to manage their own configuration
  - `common/scripts/setup_local_management.sh`: Setup script for automated local management
  - Git repository cloning and synchronization with user's fork
  - Local Terraform state management in `/opt/proxmox-firewall/terraform-state/`
  - Automated updates every 15 minutes via systemd timer or cron
  - Comprehensive logging and status reporting
  - Automatic backups before applying changes
  - Security audit integration before updates
- **Management Scripts**: 
  - `local_update.sh`: Automated update process with git sync, Ansible maintenance, and Terraform apply
  - `local_status.sh`: Status dashboard showing repository state, Terraform resources, and recent activity
- **Documentation**: `docs/LOCAL_MANAGEMENT.md` - Comprehensive guide for setup and operation

#### Security Enhancements
- **Enhanced .gitignore**: Comprehensive security patterns for Infrastructure-as-Code projects
  - All sensitive file types: SSH keys, certificates, API tokens, environment files
  - Terraform state files and variables protection
  - Ansible vault files and sensitive directories
  - Development and build artifacts exclusion
- **Security Audit Script**: `common/scripts/security_audit.sh` for pre-commit validation
  - Scans for accidentally committed sensitive files
  - Validates .gitignore completeness
  - Checks environment variable configuration
  - Verifies SSH key permissions
  - Detects hardcoded secrets in configuration files
- **Security Documentation**: Enhanced README.md and CONTRIBUTING.md with security guidelines
  - Pre-contribution security checklist
  - Emergency procedures for leaked secrets
  - Best practices for environment variables

### Changed

#### Infrastructure Management
- **Fork-First Strategy**: Enhanced repository for safe public forking
  - Users encouraged to fork for private infrastructure management
  - Local Terraform state eliminates shared state security concerns
  - Automated sync between user's fork and local Proxmox server
- **State Management**: Moved from remote to local Terraform state
  - Template: `common/terraform/terraform-local-backend.tf.example`
  - Secure local storage with proper permissions
  - Backup integration for state protection

#### Security Patterns
- **Refined .gitignore**: Made patterns more specific to avoid blocking legitimate files
  - Changed overly broad `*local*` pattern to specific configuration file patterns
  - Preserved security while allowing management scripts
  - Better organization with security-focused sections

### Fixed

#### File Access
- **Git Ignore Patterns**: Fixed overly broad `*local*` pattern blocking legitimate management scripts
- **Script Permissions**: Ensured all management scripts maintain executable permissions

## [0.43.0] - 2025-06-12

### Added

#### Documentation & Project Structure
- **Professional README.md**: Transformed into enterprise-grade open source project format
  - Added professional badges (License: MIT, CI Status, Ansible, Terraform, Python)
  - Created comprehensive navigation menu and documentation table
  - Added architecture diagram with Mermaid visualization
  - Included benefits section, contributing guidelines, and acknowledgments
- **Comprehensive Documentation Suite**:
  - `CONTRIBUTING.md`: Complete contributing guide with development environment setup, code style guidelines, pull request process
  - `SECURITY.md`: Comprehensive security policy with vulnerability reporting, best practices, and compliance information
  - `docs/TROUBLESHOOTING.md`: Detailed troubleshooting guide for installation, network, VM, and security issues
  - `docs/API.md`: Complete API documentation for Proxmox VE, OPNsense, and Tailscale with examples
  - `docs/README.md`: Documentation index organizing all materials into logical categories
  - `docs/reference/FAQ.md`: Comprehensive FAQ covering setup, configuration, security, and troubleshooting
- **GitHub Issue Templates**: Professional issue reporting structure
  - Bug report template with component selection and environment details
  - Feature request template with priority and use case sections
  - Documentation issue template for reporting doc problems
  - Question/support template for help requests
  - Pull request template with comprehensive checklists
  - Configuration file with quick links to resources

#### Scripts & Automation
- **Fork Setup Script**: `scripts/setup-fork.sh` for easy repository customization
  - Automatically updates all GitHub URLs to user's fork
  - Creates backups and provides next steps
  - Cross-platform compatibility (Linux/macOS)
- **Script Organization**: Moved `fetch_credentials.sh` from `deployment/scripts/` to `common/scripts/`
  - Now accessible from both deployment and local operations
  - Updated all documentation references
  - Maintains executable permissions

#### Project Infrastructure
- **MIT License**: Added proper open source license
- **Contact Information**: Added professional contact channels
  - General repository inquiries: github@fyberlabs.com
  - Security issues: security@fyberlabs.com
  - GitHub Discussions for community support
- **Domain Updates**: Updated all references from "fyber-labs.com" to "fyberlabs.com"
- **GitHub URLs**: Updated all repository references to correct FyberLabs organization

### Fixed

#### Configuration & Deployment
- **Hostname Usage**: Implemented hostname for site config in local ansible
- **Master Playbook**: Cleaned up the masters mess
- **Cron Job Loader**: Implemented for local operations
- **Script References**: Resolved all missing script documentation issues

#### Documentation Consistency
- **URL Standardization**: All GitHub URLs now point to `https://github.com/FyberLabs/proxmox-firewall`
- **Script Paths**: All script references now point to correct locations
- **Contact Information**: Consistent contact details across all documentation

### Changed

#### Project Presentation
- **Professional Appearance**: README now looks like a professional open source project
- **Better Organization**: Documentation organized into logical categories with clear navigation
- **User Experience**: Added "star this repo" call-to-action and professional footer
- **Community Focus**: Enhanced contributing guidelines and community engagement features

#### Development Workflow
- **Issue Management**: Structured templates for better issue triage and resolution
- **Contribution Process**: Clear guidelines for code style, testing, and pull requests
- **Documentation Standards**: Established standards for maintaining high-quality documentation

### Infrastructure

#### Validation & Testing
- **Script Validation**: Confirmed all referenced scripts exist and are functional
  - `./deployment/scripts/prerequisites.sh`
  - `./deployment/scripts/download_latest_images.sh`
  - `./deployment/scripts/create_site_config.sh`
  - `./common/scripts/add_device.sh`
  - `./common/scripts/fetch_credentials.sh`
  - `./validate-config.sh`
  - `./scripts/setup-fork.sh`
  - `./deployment/scripts/render_template.py`
- **Configuration Templates**: Extensive device template collection (20+ device types)
- **Environment Setup**: Proper `env.example` template

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
