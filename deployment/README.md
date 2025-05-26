# Deployment Scripts

This directory contains the initial deployment scripts for setting up a new Proxmox firewall system.

## Contents

- ansible/: Initial Ansible playbooks for Proxmox setup
- scripts/: Helper scripts for deployment process

## New Deployment Approach

We've reorganized the deployment process to better handle multi-site configurations:

1. **Initial ISO Creation**: Build a custom Proxmox ISO for initial installation
2. **Site-Specific Deployment**: Use the `deploy_site.sh` script to configure a site

### Using the Site Deployment Script

The `deploy_site.sh` script provides a simplified interface for deploying to a specific site:

```bash
# Deploy to a site by name
./scripts/deploy_site.sh --site primary

# Deploy to a site by IP address (will auto-detect site name from hostname)
./scripts/deploy_site.sh --ip 192.168.1.10

# Configure only networking for a site
./scripts/deploy_site.sh --site office --operation network

# Configure only security components
./scripts/deploy_site.sh --site remote --operation security
```

### Site Deployment Playbook

The `site_deployment.yml` playbook replaces the previous `master_playbook.yml` and provides:

- Clear separation of deployment phases
- Better handling of site-specific configurations
- Support for determining site name from hostname or IP address
- Improved error handling and status reporting

### Workflow

1. Create site configuration in `common/config/sites/<site_name>.yml`
2. Build and boot from the Proxmox installation ISO
3. After initial boot, run the site deployment script:

   ```bash
   ./scripts/deploy_site.sh --site <site_name>
   ```

4. The system will configure:
   - Network settings based on site configuration
   - VM templates and deployment
   - Firewall and security components
   - Local maintenance scripts and cron jobs

### Post-Deployment

After deployment, local maintenance tasks will run automatically via the cron jobs set up in the Proxmox host.
