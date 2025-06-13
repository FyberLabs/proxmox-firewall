#!/bin/bash
# add_device.sh - Script to add devices to network configurations
#
# This script helps add devices to existing firewall sites using Jinja2 templates.
# It guides users through selecting templates and configuring them
# before rendering and saving the final device configuration.
#
# Features:
# - Supports Jinja2 templates for flexible device configuration
# - Interactive template and example selection
# - Saves both template configuration and rendered result
# - Integrates with the multi-site system
# - Updates Ansible group_vars and environment variables

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

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$PROJECT_ROOT"
CONFIG_DIR="${PROJECT_ROOT}/config"
SITES_DIR="${CONFIG_DIR}/sites"
DEVICES_DIR="${CONFIG_DIR}/devices"
TEMPLATES_DIR="${CONFIG_DIR}/devices_templates"
EXAMPLES_DIR="${TEMPLATES_DIR}/examples"
TEMP_DIR="/tmp/device_config_$$"

# Create necessary directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${DEVICES_DIR}"
mkdir -p "${TEMP_DIR}"

# Color configuration
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}       Proxmox Firewall - Device Configuration Tool         ${NC}"
echo -e "${BLUE}============================================================${NC}"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo -e "${RED}Error: 'yq' is required but not installed.${NC}"
    echo -e "Please install yq: https://github.com/mikefarah/yq"
    echo -e "On Ubuntu/Debian: sudo apt-get install yq"
    echo -e "On macOS: brew install yq"
    exit 1
fi

# Check if Python and required modules are installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not installed.${NC}"
    exit 1
fi

# Check for jinja2 and pyyaml
if ! python3 -c "import jinja2, yaml" &> /dev/null; then
    echo -e "${RED}Error: Python modules 'jinja2' and 'pyyaml' are required.${NC}"
    echo -e "Please install: pip3 install jinja2 pyyaml"
    exit 1
fi

# Cleanup function
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Function to list available sites
list_sites() {
    echo -e "${GREEN}Available sites:${NC}"
    if [ ! -d "${SITES_DIR}" ] || [ -z "$(ls -A ${SITES_DIR}/*.yml 2>/dev/null)" ]; then
        echo -e "${RED}No sites configured yet.${NC}"
        echo -e "${YELLOW}Please run scripts/create_site_config.sh first to create a site.${NC}"
        return 1
    fi

    for site_file in "${SITES_DIR}"/*.yml; do
        site_name=$(basename "${site_file}" .yml)
        display_name=$(yq -r '.site.display_name // .site.name' "${site_file}")
        network_prefix=$(yq -r '.site.network_prefix' "${site_file}")
        echo -e "  ${BLUE}${site_name}${NC} - ${display_name} (${network_prefix}.x.x)"
    done
}

# Function to list available device templates
list_device_templates() {
    echo -e "${GREEN}Available device templates:${NC}"
    if [ ! -d "${TEMPLATES_DIR}" ] || [ -z "$(ls -A ${TEMPLATES_DIR}/*.yml.j2 2>/dev/null)" ]; then
        echo -e "${RED}No device templates found.${NC}"
        return 1
    fi

    for template_file in "${TEMPLATES_DIR}"/*.yml.j2; do
        template_name=$(basename "${template_file}" .yml.j2)
        if [ -f "${template_file}" ]; then
            # Try to extract description from template
            description=$(grep -E "^#.*description:" "${template_file}" | head -1 | sed 's/^#.*description: *//' || echo "No description available")
            echo -e "  ${BLUE}${template_name}${NC} - ${description}"
        fi
    done
}

# Function to list available example configurations
list_examples() {
    echo -e "${GREEN}Available example configurations:${NC}"
    if [ -z "$(ls -A ${EXAMPLES_DIR}/*.yml 2>/dev/null)" ]; then
        echo -e "${RED}No example configurations found.${NC}"
        return 1
    fi

    echo -e "${BLUE}Example Name\tTemplate\tDescription${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    for example_file in "${EXAMPLES_DIR}"/*.yml; do
        example_name=$(basename "${example_file}" .yml)
        template=$(grep "^template:" "${example_file}" | cut -d':' -f2- | xargs)
        description=$(grep "^# " "${example_file}" | head -1 | cut -d'#' -f2- | xargs)
        printf "${GREEN}%-15s${NC}\t${GREEN}%-15s${NC}\t${GREEN}%s${NC}\n" "${example_name}" "${template}" "${description}"
    done
}

# Function to create starter configuration for a template
create_starter_config() {
    local template_file=$1
    local template_name=$(basename "${template_file}" .yml.j2)

    # Create template-specific starter configurations
    case $template_name in
        "nvr")
            cat <<EOL
# Configuration for nvr.yml.j2
template: nvr.yml.j2

# Basic device information
nvr_type: "Network Video Recorder for security cameras"
vlan: 20
ip_suffix: 3

# Network configuration
mac_address: "XX:XX:XX:XX:XX:XX"  # Replace XX with actual MAC address

# Network ports
web_port: 443
rtsp_port: 9000
mobile_app_port: 8000

# Features
rtsp_enabled: true
onvif_enabled: false
mobile_app_enabled: true

# Security settings
allow_internet: false
allow_local_network: false
needs_dhcp_reservation: true
EOL
            ;;
        "homeassistant")
            cat <<EOL
# Configuration for homeassistant.yml.j2
template: homeassistant.yml.j2

# Basic device information
vlan: 10
ip_suffix: 10

# Network configuration
mac_address: "XX:XX:XX:XX:XX:XX"  # Replace XX with actual MAC address

# Network ports
web_port: 8123
mqtt_port: 1883
mdns_port: 5353

# Security settings
allow_internet: true
allow_local_network: true
needs_dhcp_reservation: true
EOL
            ;;
        "nas")
            cat <<EOL
# Configuration for nas.yml.j2
template: nas.yml.j2

# Basic device information
nas_type: "Network Attached Storage"
vlan: 10
ip_suffix: 100

# Network configuration
mac_address: "XX:XX:XX:XX:XX:XX"  # Replace XX with actual MAC address

# Network ports
web_port: 80
https_port: 443
smb_port: 445
ssh_port: 22
nfs_port: 2049

# Features
smb_enabled: true
nfs_enabled: true
web_ui_enabled: true

# Security settings
allow_internet: false
allow_local_network: true
needs_dhcp_reservation: true
EOL
            ;;
        "camera")
            cat <<EOL
# Configuration for camera.yml.j2
template: camera.yml.j2

# Basic device information
camera_type: "IP Security Camera"
vlan: 20
ip_suffix: 21

# Network configuration
mac_address: "XX:XX:XX:XX:XX:XX"  # Replace XX with actual MAC address

# Network ports
rtsp_port: 554
http_port: 80
https_port: 443

# Features
rtsp_enabled: true
http_enabled: true
https_enabled: true
onvif_enabled: true

# Security settings
allow_internet: false
allow_local_network: false
needs_dhcp_reservation: true
EOL
            ;;
        *)
            # Generic template for unknown types
            cat <<EOL
# Configuration for ${template_name}.yml.j2
template: ${template_name}.yml.j2

# Basic device information
vlan: 10
ip_suffix: 50

# Network configuration
mac_address: "XX:XX:XX:XX:XX:XX"  # Replace XX with actual MAC address

# Security settings
allow_internet: false
allow_local_network: true
needs_dhcp_reservation: true

# Add your specific configuration here
EOL
            ;;
    esac
}

# Function to add a device to a site
add_device() {
    # Check dependencies first
    check_dependencies

    # List available sites
    list_sites
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Get site selection
    echo -e "\n${GREEN}Enter the site name:${NC}"
    read site_name

    if [ ! -f "${SITES_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load site configuration
    SITE_DISPLAY_NAME=$(yq -r '.site.display_name // .site.name' "${SITES_DIR}/${site_name}.yml")
    NETWORK_PREFIX=$(yq -r '.site.network_prefix' "${SITES_DIR}/${site_name}.yml")
    DOMAIN=$(yq -r '.site.domain' "${SITES_DIR}/${site_name}.yml")

    echo -e "${GREEN}Selected site: ${SITE_DISPLAY_NAME} (${NETWORK_PREFIX}.x.x)${NC}"

    # List available templates
    echo -e "\n"
    list_device_templates
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Get template selection
    echo -e "\n${GREEN}Enter the device template name:${NC}"
    read template_name

    template_file="${TEMPLATES_DIR}/${template_name}.yml.j2"
    if [ ! -f "${template_file}" ]; then
        echo -e "${RED}Error: Template '${template_name}' not found${NC}"
        return 1
    fi

    # Get device name
    echo -e "\n${GREEN}Enter a unique name for this device (e.g., 'front_camera', 'main_nas'):${NC}"
    read device_name

    # Validate device name
    if [[ ! "${device_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Device name can only contain letters, numbers, underscores, and hyphens${NC}"
        return 1
    fi

    # Check if device already exists in site
    if yq -e ".devices.${device_name}" "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
        echo -e "${RED}Error: Device '${device_name}' already exists in site '${site_name}'${NC}"
        return 1
    fi

    # Create temporary config file for template rendering
    tmp_config="${TEMP_DIR}/${device_name}.config"
    cat > "${tmp_config}" <<EOL
# Configuration for ${template_name}.yml.j2
template: ${template_name}.yml.j2
device_name: ${device_name}
site_name: ${site_name}
network_prefix: ${NETWORK_PREFIX}
domain: ${DOMAIN}
EOL

    # Render template to get default values
    temp_rendered="${TEMP_DIR}/${device_name}.yml"
    if ! python3 "${PROJECT_ROOT}/deployment/scripts/render_template.py" "${tmp_config}" -o "${temp_rendered}" -t "${TEMPLATES_DIR}"; then
        echo -e "${RED}Error: Failed to render template${NC}"
        return 1
    fi

    # Extract default values from rendered template
    device_type=$(yq -r '.type' "${temp_rendered}")
    default_vlan=$(yq -r '.vlan // 10' "${temp_rendered}")
    default_ip_suffix=$(yq -r '.ip_suffix // 100' "${temp_rendered}")
    default_ports=$(yq -r '.ports[]?' "${temp_rendered}" | tr '\n' ',' | sed 's/,$//')

    # Interactive configuration
    echo -e "\n${BLUE}=== Device Configuration ===${NC}"
    echo -e "Device type: ${device_type}"

    # Get VLAN
    echo -e "\n${GREEN}Enter VLAN ID [${default_vlan}]:${NC}"
    read vlan_input
    vlan_id=${vlan_input:-$default_vlan}

    # Get IP suffix
    echo -e "\n${GREEN}Enter IP address suffix (for ${NETWORK_PREFIX}.${vlan_id}.X) [${default_ip_suffix}]:${NC}"
    read ip_suffix_input
    ip_suffix=${ip_suffix_input:-$default_ip_suffix}

    # Calculate full IP
    ip_address="${NETWORK_PREFIX}.${vlan_id}.${ip_suffix}"

        # Get MAC address (optional)
    echo -e "\n${GREEN}Enter MAC address (format: XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX) or press Enter to use placeholder:${NC}"
    read mac_address_input

    # Handle MAC address input
    if [ -z "${mac_address_input}" ]; then
        mac_address="XX:XX:XX:XX:XX:XX"
        echo -e "${YELLOW}Using placeholder MAC address. You can edit this later in the device file.${NC}"
    else
        # Normalize MAC address format (accept both : and - separators)
        mac_address=$(echo "${mac_address_input}" | tr '-' ':' | tr '[:lower:]' '[:upper:]')

        # Validate MAC address format
        if [[ ! "${mac_address}" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            echo -e "${RED}Error: Invalid MAC address format. Use XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX${NC}"
            return 1
        fi

        echo -e "${GREEN}Normalized MAC address: ${mac_address}${NC}"
    fi

    # Show ports if available
    if [ -n "${default_ports}" ]; then
        echo -e "\n${GREEN}Default ports for this device type: ${default_ports}${NC}"
        echo -e "${GREEN}Enter additional ports (comma-separated) or press Enter to use defaults:${NC}"
        read additional_ports
    fi

    # Update the config file with user inputs
    cat >> "${tmp_config}" <<EOL

# User configuration
vlan: ${vlan_id}
ip_suffix: ${ip_suffix}
mac_address: "${mac_address}"
EOL

    if [ -n "${additional_ports}" ]; then
        echo "additional_ports: [${additional_ports}]" >> "${tmp_config}"
    fi

    # Re-render template with user configuration
    if ! python3 "${PROJECT_ROOT}/deployment/scripts/render_template.py" "${tmp_config}" -o "${temp_rendered}" -t "${TEMPLATES_DIR}"; then
        echo -e "${RED}Error: Failed to render template with user configuration${NC}"
        return 1
    fi

    # Show final configuration for confirmation
    echo -e "\n${BLUE}=== Final Device Configuration ===${NC}"
    echo -e "Device name: ${device_name}"
    echo -e "Type: ${device_type}"
    echo -e "IP address: ${ip_address}"
    echo -e "VLAN: ${vlan_id}"
    echo -e "MAC address: ${mac_address}"

    echo -e "\n${YELLOW}Configuration preview:${NC}"
    cat "${temp_rendered}"

    echo -e "\n${GREEN}Add this device to ${SITE_DISPLAY_NAME}? (y/n):${NC}"
    read confirm

    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        return 0
    fi

    # Add device to site YAML file
    add_device_to_site "${site_name}" "${device_name}" "${temp_rendered}"

    echo -e "\n${GREEN}✓ Device '${device_name}' successfully added to site '${site_name}'${NC}"
    echo -e "${YELLOW}Individual device file: ${DEVICES_DIR}/${site_name}/${device_name}.yml${NC}"
    echo -e "${YELLOW}Site reference: ${SITES_DIR}/${site_name}.yml${NC}"
    echo -e "${YELLOW}Run your deployment automation to apply these changes.${NC}"
}

# Function to add device configuration to site YAML file
add_device_to_site() {
    local site_name=$1
    local device_name=$2
    local rendered_config=$3
    local site_file="${SITES_DIR}/${site_name}.yml"
    local site_devices_dir="${DEVICES_DIR}/${site_name}"
    local device_file="${site_devices_dir}/${device_name}.yml"

    # Create site-specific devices directory
    mkdir -p "${site_devices_dir}"

    # Create a backup of site file
    cp "${site_file}" "${site_file}.bak"

    # Extract device configuration from rendered file
    local device_type=$(yq -r '.type' "${rendered_config}")
    local device_ip=$(yq -r '.ip_address // empty' "${rendered_config}")
    local device_vlan=$(yq -r '.vlan // empty' "${rendered_config}")
    local device_mac=$(yq -r '.mac_address // empty' "${rendered_config}")

    # If ip_address is not in rendered config, construct it
    if [ -z "${device_ip}" ] || [ "${device_ip}" = "null" ]; then
        local network_prefix=$(yq -r '.site.network_prefix' "${site_file}")
        local ip_suffix=$(yq -r '.ip_suffix // 100' "${rendered_config}")
        device_ip="${network_prefix}.${device_vlan}.${ip_suffix}"
    fi

    # Create individual device YAML file
    cp "${rendered_config}" "${device_file}"

    # Update the device file with the calculated IP address
    python3 -c "
import yaml

# Load device config
with open('${device_file}', 'r') as f:
    device_data = yaml.safe_load(f)

# Update IP address
device_data['ip_address'] = '${device_ip}'

# Write back to device file
with open('${device_file}', 'w') as f:
    yaml.dump(device_data, f, default_flow_style=False, sort_keys=False)
"

    # Add device reference to site YAML file
    local temp_site_config="${TEMP_DIR}/site_config.yml"
    python3 -c "
import yaml
import os

# Load site config
with open('${site_file}', 'r') as f:
    site_data = yaml.safe_load(f)

# Ensure devices section exists
if 'devices' not in site_data:
    site_data['devices'] = {}

# Add device reference (just basic info for quick reference)
site_data['devices']['${device_name}'] = {
    'type': '${device_type}',
    'ip_address': '${device_ip}',
    'vlan_id': ${device_vlan},
    'mac_address': '${device_mac}',
    'config_file': 'config/devices/${site_name}/${device_name}.yml'
}

# Write back to site file
with open('${temp_site_config}', 'w') as f:
    yaml.dump(site_data, f, default_flow_style=False, sort_keys=False)
"

    # Replace the original site file
    mv "${temp_site_config}" "${site_file}"

    echo -e "${GREEN}✓ Device file created: ${device_file}${NC}"
    echo -e "${GREEN}✓ Device reference added to site: ${site_file}${NC}"
}

# Function to list devices for a site
list_devices() {
    list_sites
    echo -e "\n${GREEN}Enter the site name:${NC}"
    read site_name

    if [ ! -f "${SITES_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load site config from YAML
    SITE_DISPLAY_NAME=$(yq -r '.site.display_name // .site.name' "${SITES_DIR}/${site_name}.yml")
    local site_devices_dir="${DEVICES_DIR}/${site_name}"

    # Check if devices exist (either in site YAML or device directory)
    local has_devices=false
    if yq -e '.devices' "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
        has_devices=true
    elif [ -d "${site_devices_dir}" ] && [ -n "$(ls -A ${site_devices_dir}/*.yml 2>/dev/null)" ]; then
        has_devices=true
    fi

    if [ "$has_devices" = false ]; then
        echo -e "${RED}No devices configured for ${SITE_DISPLAY_NAME}${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Devices for ${SITE_DISPLAY_NAME}:${NC}"
    echo -e "${BLUE}Device Name\t\tType\t\tVLAN\tIP Address\t\tConfig File${NC}"
    echo -e "${BLUE}---------------------------------------------------------------------------------${NC}"

    # List devices from site YAML (with config_file references)
    if yq -e '.devices' "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
        yq -r '.devices | to_entries[] | select(.value.type != null) | [.key, .value.type, .value.vlan_id, .value.ip_address, (.value.config_file // "inline")] | @tsv' "${SITES_DIR}/${site_name}.yml" | \
        while IFS=$'\t' read -r device_name device_type device_vlan device_ip config_file; do
            printf "${GREEN}%-20s${NC}\t${GREEN}%-15s${NC}\t${GREEN}%-5s${NC}\t${GREEN}%-15s${NC}\t${GREEN}%s${NC}\n" "${device_name}" "${device_type}" "${device_vlan}" "${device_ip}" "${config_file}"
        done
    fi

    # Also list any standalone device files that might not be referenced in site YAML
    if [ -d "${site_devices_dir}" ]; then
        for device_file in "${site_devices_dir}"/*.yml; do
            if [ -f "${device_file}" ]; then
                device_name=$(basename "${device_file}" .yml)
                # Check if this device is already listed in site YAML
                if ! yq -e ".devices.${device_name}" "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
                    device_type=$(yq -r '.type // "unknown"' "${device_file}")
                    device_vlan=$(yq -r '.vlan // .vlan_id // "unknown"' "${device_file}")
                    device_ip=$(yq -r '.ip_address // "unknown"' "${device_file}")
                    config_file="config/devices/${site_name}/${device_name}.yml"
                    printf "${YELLOW}%-20s${NC}\t${YELLOW}%-15s${NC}\t${YELLOW}%-5s${NC}\t${YELLOW}%-15s${NC}\t${YELLOW}%s${NC} ${RED}(orphaned)${NC}\n" "${device_name}" "${device_type}" "${device_vlan}" "${device_ip}" "${config_file}"
                fi
            fi
        done
    fi
}

# Function to remove a device
remove_device() {
    list_sites
    echo -e "\n${GREEN}Enter the site name:${NC}"
    read site_name

    if [ ! -f "${SITES_DIR}/${site_name}.yml" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load site config from YAML
    SITE_DISPLAY_NAME=$(yq -r '.site.display_name // .site.name' "${SITES_DIR}/${site_name}.yml")
    local site_devices_dir="${DEVICES_DIR}/${site_name}"

    # Check if devices exist
    local has_devices=false
    if yq -e '.devices' "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
        has_devices=true
    elif [ -d "${site_devices_dir}" ] && [ -n "$(ls -A ${site_devices_dir}/*.yml 2>/dev/null)" ]; then
        has_devices=true
    fi

    if [ "$has_devices" = false ]; then
        echo -e "${RED}No devices configured for ${SITE_DISPLAY_NAME}${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Devices for ${SITE_DISPLAY_NAME}:${NC}"
    echo -e "${BLUE}Device Name\t\tType\t\tIP Address${NC}"
    echo -e "${BLUE}------------------------------------------------${NC}"

    # List devices from site YAML
    if yq -e '.devices' "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
        yq -r '.devices | to_entries[] | select(.value.type != null) | [.key, .value.type, .value.ip_address] | @tsv' "${SITES_DIR}/${site_name}.yml" | \
        while IFS=$'\t' read -r device_name device_type device_ip; do
            printf "${GREEN}%-20s${NC}\t${GREEN}%-15s${NC}\t${GREEN}%s${NC}\n" "${device_name}" "${device_type}" "${device_ip}"
        done
    fi

    # Also list standalone device files
    if [ -d "${site_devices_dir}" ]; then
        for device_file in "${site_devices_dir}"/*.yml; do
            if [ -f "${device_file}" ]; then
                device_name=$(basename "${device_file}" .yml)
                if ! yq -e ".devices.${device_name}" "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
                    device_type=$(yq -r '.type // "unknown"' "${device_file}")
                    device_ip=$(yq -r '.ip_address // "unknown"' "${device_file}")
                    printf "${YELLOW}%-20s${NC}\t${YELLOW}%-15s${NC}\t${YELLOW}%s${NC} ${RED}(file only)${NC}\n" "${device_name}" "${device_type}" "${device_ip}"
                fi
            fi
        done
    fi

    echo -e "\n${GREEN}Enter the name of the device to remove:${NC}"
    read device_name

    # Check if device exists in site YAML or as individual file
    local device_in_site=false
    local device_file_exists=false
    local device_file="${site_devices_dir}/${device_name}.yml"

    if yq -e ".devices.${device_name}" "${SITES_DIR}/${site_name}.yml" >/dev/null 2>&1; then
        device_in_site=true
    fi

    if [ -f "${device_file}" ]; then
        device_file_exists=true
    fi

    if [ "$device_in_site" = false ] && [ "$device_file_exists" = false ]; then
        echo -e "${RED}Error: Device '${device_name}' not found${NC}"
        return 1
    fi

    # Confirm deletion
    echo -e "${YELLOW}Are you sure you want to remove ${device_name} from ${SITE_DISPLAY_NAME}?"
    if [ "$device_in_site" = true ]; then
        echo -e "${YELLOW}  - Remove from site YAML file${NC}"
    fi
    if [ "$device_file_exists" = true ]; then
        echo -e "${YELLOW}  - Delete individual device file: ${device_file}${NC}"
    fi
    echo -e "${YELLOW}(y/n)${NC}"
    read confirm

    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${GREEN}Operation cancelled.${NC}"
        return 0
    fi

    # Create backup of site file
    if [ "$device_in_site" = true ]; then
        cp "${SITES_DIR}/${site_name}.yml" "${SITES_DIR}/${site_name}.yml.bak"

        # Remove device from site YAML using Python
        python3 -c "
import yaml

# Load site config
with open('${SITES_DIR}/${site_name}.yml', 'r') as f:
    site_data = yaml.safe_load(f)

# Remove device
if 'devices' in site_data and '${device_name}' in site_data['devices']:
    del site_data['devices']['${device_name}']

# Write back to file
with open('${SITES_DIR}/${site_name}.yml', 'w') as f:
    yaml.dump(site_data, f, default_flow_style=False, sort_keys=False)
"
        echo -e "${GREEN}✓ Device removed from site YAML${NC}"
    fi

    # Remove individual device file
    if [ "$device_file_exists" = true ]; then
        rm -f "${device_file}"
        echo -e "${GREEN}✓ Device file deleted: ${device_file}${NC}"
    fi

    echo -e "${GREEN}Device ${device_name} removed from ${SITE_DISPLAY_NAME}${NC}"
    echo -e "${YELLOW}Run your deployment automation to apply these changes.${NC}"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi

    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install the missing dependencies and try again.${NC}"
        exit 1
    fi
}

# Main menu
while true; do
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${GREEN}Device Configuration Tool Options:${NC}"
    echo -e "  1. Add a new device to a site"
    echo -e "  2. List available device templates"
    echo -e "  3. List configured devices for a site"
    echo -e "  4. Remove a device from a site"
    echo -e "  q. Quit"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${GREEN}Enter your choice:${NC}"
    read choice

    case $choice in
        1)
            add_device
            ;;
        2)
            list_device_templates
            ;;
        3)
            list_devices
            ;;
        4)
            remove_device
            ;;
        q|Q)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
done
