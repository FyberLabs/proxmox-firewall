# Configuration Directory

This directory contains all user-configurable site and device definitions for the Proxmox firewall deployment system.

## Structure

```
config/
├── sites/              # Site configuration files (ONE FILE PER SITE)
│   ├── primary.yml     # Complete configuration for "primary" site
│   ├── branch.yml      # Complete configuration for "branch" site
│   └── home.yml        # Complete configuration for "home" site
├── devices/            # Working directory for device configuration scripts
├── devices_templates/  # Jinja2 templates for common device types
│   ├── camera.yml.j2
│   ├── nas.yml.j2
│   ├── homeassistant.yml.j2
│   └── custom.yml.j2
└── site_template.yml   # Template for creating new sites
```

## Device Configuration Approach

**Important**: Devices are configured **inline within each site's YAML file**, not as separate files.

### Correct Structure:
- **Device Templates**: `config/devices_templates/` - Jinja2 templates (.yml.j2)
- **Device Configs**: Inside `config/sites/{site_name}.yml` under `devices:` section
- **Working Directory**: `config/devices/` - Used by scripts during device creation

### Example Site Configuration with Devices:

```yaml
site:
  name: "primary"
  network_prefix: "10.1"
  domain: "primary.local"
  # ... other site config ...

  # Devices are configured inline within the site
  devices:
    homeassistant:
      type: "homeassistant"
      ip_address: "10.1.10.10"
      vlan_id: 10
      mac_address: "52:54:00:12:34:56"
      ports: [8123, 1883, 5353]
    
    nas:
      type: "nas"
      ip_address: "10.1.10.100"
      vlan_id: 10
      mac_address: "52:54:00:12:34:57"
      ports: [80, 443, 445, 22, 139, 2049]
    
    camera_front:
      type: "camera"
      ip_address: "10.1.20.21"
      vlan_id: 20
      mac_address: "52:54:00:12:34:58"
      ports: [80, 554, 9000]
```

## Usage

### Creating a New Site

**Recommended**: Use the site creation script:
```bash
./deployment/scripts/create_site_config.sh
```

This creates a complete YAML configuration file in `sites/` with all necessary sections including the `devices:` section.

**Manual**: Copy `site_template.yml` to `sites/your-site-name.yml` and customize.

### Site Configuration File

Each site has **one comprehensive YAML file** containing:

- Site identification (name, domain, network prefix)
- Hardware specifications (CPU, memory, storage)
- Network topology (VLANs, bridges, interfaces)
- VM templates and configurations
- **Device configurations (inline)**
- Security policies and firewall rules
- Monitoring and backup settings
- Credential references (environment variable names)

### Adding Devices

**Option 1**: Use the device management script:
```bash
./common/scripts/add_device.sh
```

This script will:
1. Help you select a device template
2. Configure device-specific settings
3. Add the device configuration to your site's YAML file

**Option 2**: Manually edit your site YAML file:
1. Add device entries under the `devices:` section
2. Follow the format shown in `site_template.yml`
3. Ensure device templates exist in `config/devices_templates/`

**Version Control Friendly**: Clean, readable YAML files with everything in one place per site

## Configuration Flow

1. **Site Creation**: Creates site YAML file with all sections
2. **Device Addition**: Adds device configs inline to site YAML file  
3. **Template Rendering**: Ansible reads site YAML and renders device configs using Jinja2 templates
4. **Deployment**: Ansible applies device configs (DHCP, firewall rules, etc.)
