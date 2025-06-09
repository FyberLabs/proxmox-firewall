# Device Configuration System

This document explains how to use the device configuration system to add and manage network devices for your Proxmox Firewall deployment.

## Overview

The device configuration system allows you to:

1. Define device templates with standardized configurations using Jinja2
2. Add specific device instances to your network sites
3. Automatically generate appropriate DHCP reservations
4. Create appropriate firewall rules based on device type
5. Maintain device configurations in version control
6. Customize device features through template variables

## Directory Structure

```
templates/
└── devices/
    ├── homeassistant.yml.j2     # Home Assistant template
    ├── nas.yml.j2               # NAS template
    ├── camera.yml.j2            # IP Camera template
    ├── nvr.yml.j2               # Network Video Recorder template
    ├── iot_hub.yml.j2           # IoT Hub template
    ├── game_console.yml.j2      # Gaming console template
    ├── desktop.yml.j2           # Desktop PC template
    ├── custom.yml.j2            # Custom device template
    └── examples/                # Example configurations
        ├── synology_nas.yml     # Example Synology NAS config
        ├── reolink_camera.yml   # Example Reolink camera config
        └── custom_kubernetes.yml # Example Kubernetes cluster config

devices/         # Rendered device configurations
config/devices/  # Site-specific device instances
```

## Requirements

The device configuration system requires:

- `yq` command-line tool for YAML processing
- Python 3 with `jinja2` and `pyyaml` modules
- An existing site configured with the `scripts/create_site_config.sh` script
- Appropriate VLAN configurations in OPNsense

## Template System

Each device type has a Jinja2 template (`.yml.j2` file) that defines:

- Basic device information (type, description)
- Network settings (VLAN, IP suffix)
- Port configurations with conditional features
- Security rules
- DHCP requirements

These templates use Jinja2 variables with sensible defaults, allowing you to:
- Override settings for specific device instances
- Conditionally include/exclude features
- Add custom port configurations
- Define device-specific settings

## Using the Device Configuration Tool

The `scripts/add_device.sh` script provides an interactive way to create devices using the template system.

### Usage

```bash
./scripts/add_device.sh
```

The script offers the following options:

1. **Create a new device from template** - Create a device by selecting a template or example
2. **List available device templates** - View all available device templates
3. **List available example configurations** - View example device configurations
4. **List configured devices for a site** - View all devices configured for a site
5. **Remove a device from a site** - Delete a device configuration

### Device Templates Overview

The system comes with several pre-defined device templates:

| Device Type | Description | VLAN | Example IP Suffix |
|-------------|-------------|------|------------------|
| homeassistant | Home automation server | 10 (Main LAN) | 10 |
| nas | Network storage (TrueNAS, Synology) | 10 (Main LAN) | 100 |
| game_console | Gaming console (PlayStation, Xbox) | 10 (Main LAN) | 50 |
| desktop | Desktop computer | 10 (Main LAN) | 101 |
| nvr | Network Video Recorder | 20 (Camera VLAN) | 3 |
| iot_hub | Smart home hub (Hue, SmartThings) | 30 (IoT VLAN) | 10 |
| camera | IP Security Camera | 20 (Camera VLAN) | 20 |
| custom | Custom device template | Any | 150 |

### Creating a New Device

When creating a new device, you can either:

1. **Start from an example** - Use one of the pre-configured example devices
2. **Start from a template** - Create a configuration from scratch using a template

The script will:
1. Ask for which site to add the device to
2. Help you select a template or example
3. Open an editor for you to customize the configuration
4. Render the template with your settings
5. Prompt for a MAC address (if DHCP is needed)
6. Update the site's device configuration

### Example Workflow

```
$ ./scripts/add_device.sh

1. Create a new device from template
2. List available device templates
3. List available example configurations
4. List configured devices for a site
5. Remove a device from a site
q. Quit

Select an option: 1

Available sites:
Site Name       Display Name
----------------------------------------
primary         Primary Home

Enter the site name of the site to add device to: primary

How would you like to create the device configuration?
  1. Use an example configuration as a starting point
  2. Create from scratch with a template
Select an option (1/2): 1

Available example configurations:
Example Name    Template        Description
----------------------------------------
synology_nas    nas.yml.j2      Synology NAS example configuration
reolink_camera  camera.yml.j2   Reolink Camera example configuration

Enter the name of the example to use: synology_nas

Enter a name for this device (e.g., living_room_nas): office_nas

Opening editor to modify device configuration...
[editor opens with the example configuration]

Rendering template...

Enter MAC address for office_nas (format xx:xx:xx:xx:xx:xx): 00:11:22:33:44:55

Device office_nas (Synology NAS DS920+) added to Primary Home!
Template configuration saved to config/devices/primary/office_nas.yml.config
Rendered device configuration saved to devices/office_nas.yml

To apply these changes:
1. Run the Ansible deployment for this site:
   ansible-playbook ansible/master_playbook.yml --limit=primary --tags=network,dhcp
```

### Applying Changes

After adding or removing devices, you need to apply the changes:

```bash
ansible-playbook ansible/master_playbook.yml --limit=<site_name> --tags=network,dhcp
```

This will:
- Update the OPNsense interface configurations
- Configure DHCP reservations for your devices
- Create appropriate firewall rules

## Manual Template Rendering

If you prefer to create device configurations manually:

### 1. Create a Device Configuration

Create a YAML file for your specific device, specifying:

- The template to use
- Any variables to override default settings

Example (`my_nas.yml`):

```yaml
# My Synology NAS configuration
template: nas.yml.j2

# Basic device information
nas_type: "Synology DS920+"
vlan: 10
ip_suffix: 100

# Enabled services
smb_enabled: true
nfs_enabled: true
web_ui_enabled: true
web_ui_port: 5001
docker_enabled: true
plex_enabled: true

# Security settings
allow_internet: false
allow_local_network: true
```

### 2. Render the Configuration

Use the `scripts/render_template.py` script to generate the final device configuration:

```bash
./scripts/render_template.py my_nas.yml -o devices/my_nas.yml
```

This will:
1. Load the YAML configuration
2. Apply it to the specified template
3. Generate the final device configuration file

## Creating Custom Device Templates

To create a new device type:

1. Start with the `custom.yml.j2` template as a reference
2. Create a new template file in `templates/devices/`
3. Define default values and conditional logic
4. Document the available configuration options

Example of a custom template:

```yaml
# Custom device template example
type: my_device
description: "My Custom Device Type"
vlan: 10  # Main LAN
ip_suffix: 120
ports:
  - port: 8080
    protocol: tcp
    description: "Web interface"
  - port: 5000
    protocol: tcp
    description: "API"
allow_internet: true
allow_local_network: true
needs_dhcp_reservation: true
```

## Available Device Templates and Variables

### Home Assistant (`homeassistant.yml.j2`)

**Variables:**
- `vlan`: VLAN ID (default: 10)
- `ip_suffix`: IP address suffix (default: 10)
- `web_port`: Web UI port (default: 8123)
- `sonos_integration`: Enable Sonos integration (default: false)
- `zwave_integration`: Enable Z-Wave integration (default: false)
- `mqtt_integration`: Enable MQTT broker (default: true)
- `additional_ports`: List of additional ports to expose
- `allow_internet`: Allow internet access (default: true)
- `allow_local_network`: Allow local network access (default: true)
- `needs_dhcp_reservation`: Configure DHCP reservation (default: true)

### NAS (`nas.yml.j2`)

**Variables:**
- `nas_type`: Description of NAS (default: "Network Attached Storage")
- `vlan`: VLAN ID (default: 10)
- `ip_suffix`: IP address suffix (default: 100)
- `smb_enabled`: Enable SMB file sharing (default: true)
- `nfs_enabled`: Enable NFS file sharing (default: true)
- `web_ui_enabled`: Enable web UI (default: true)
- `web_ui_port`: Web UI port (default: 443)
- `ssh_enabled`: Enable SSH access (default: false)
- `iscsi_enabled`: Enable iSCSI (default: false)
- `afp_enabled`: Enable AFP (default: false)
- `docker_enabled`: Enable Docker containers (default: false)
- `plex_enabled`: Enable Plex Media Server (default: false)
- `additional_ports`: List of additional ports to expose
- `allow_internet`: Allow internet access (default: false)
- `allow_local_network`: Allow local network access (default: true)
- `needs_dhcp_reservation`: Configure DHCP reservation (default: true)

### Camera (`camera.yml.j2`)

**Variables:**
- `camera_type`: Camera model description (default: "IP Security Camera")
- `vlan`: VLAN ID (default: 20)
- `ip_suffix`: IP address suffix (default: 20)
- `rtsp_enabled`: Enable RTSP streaming (default: true)
- `rtsp_port`: RTSP port (default: 554)
- `http_enabled`: Enable HTTP interface (default: true)
- `http_port`: HTTP port (default: 80)
- `https_enabled`: Enable HTTPS interface (default: false)
- `https_port`: HTTPS port (default: 443)
- `onvif_enabled`: Enable ONVIF discovery (default: true)
- `additional_ports`: List of additional ports to expose
- `nvr_ip`: IP of NVR managing this camera
- `allow_internet`: Allow internet access (default: false)
- `allow_local_network`: Allow local network access (default: false)
- `needs_dhcp_reservation`: Configure DHCP reservation (default: true)
- `nvr_managed`: Camera is managed by NVR (default: true)

## How it Works

The device configuration system:

1. Stores templates in the `templates/devices/`
