# Configuration Directory

This directory contains all user-configurable site and device definitions for the Proxmox firewall deployment system.

## Structure

```
config/
├── sites/              # Site configuration files (ONE FILE PER SITE)
│   ├── primary.yml     # Complete configuration for "primary" site
│   ├── branch.yml      # Complete configuration for "branch" site
│   └── home.yml        # Complete configuration for "home" site
├── devices/            # Device configuration files (optional, organized by site)
│   ├── primary/        # Devices for primary site
│   │   ├── camera1.yml
│   │   └── switch1.yml
│   └── branch/         # Devices for branch site
│       └── ap1.yml
├── devices_templates/  # Device templates for common device types
│   ├── camera.yml
│   ├── switch.yml
│   └── access_point.yml
└── site_template.yml   # Template for creating new sites
```

## Usage

### Creating a New Site

**Recommended**: Use the site creation script:
```bash
./deployment/scripts/create_site_config.sh
```

This creates a complete YAML configuration file in `sites/` with all necessary sections.

**Manual**: Copy `site_template.yml` to `sites/your-site-name.yml` and customize.

### Site Configuration File

Each site has **one comprehensive YAML file** containing:

- Site identification (name, domain, network prefix)
- Hardware specifications (CPU, memory, storage)
- Network topology (VLANs, bridges, interfaces)
- VM templates and configurations
- Security policies and firewall rules
- Monitoring and backup settings
- Credential references (environment variable names)

### Adding Devices (Optional)

For complex sites with many network devices:

```bash
./common/scripts/add_device.sh
```

Or manually create device configurations in `devices/<site_name>/`

**Version Control Friendly**: Clean, readable YAML files

## Configuration Flow

1. **User creates/edits** `sites/site-name.yml`
2. **Ansible reads** the YAML file directly
3. **Ansible passes values** to Terraform via environment variables
4. **Terraform deploys** infrastructure using those values
