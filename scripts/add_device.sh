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

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATES_DIR="${SCRIPT_DIR}/templates/devices"
EXAMPLES_DIR="${TEMPLATES_DIR}/examples"
RENDERED_DIR="${SCRIPT_DIR}/devices"
SITE_DEVICES_DIR="${CONFIG_DIR}/devices"
ANSIBLE_GROUP_VARS_DIR="${SCRIPT_DIR}/ansible/group_vars"

# Create necessary directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${RENDERED_DIR}"
mkdir -p "${SITE_DEVICES_DIR}"

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

# Function to list available sites
list_sites() {
    echo -e "\n${GREEN}Available sites:${NC}"
    if [ -z "$(ls -A ${CONFIG_DIR}/*.conf 2>/dev/null)" ]; then
        echo -e "${RED}No sites configured yet.${NC}"
        echo -e "${YELLOW}Please run scripts/create_site_config.sh first to create a site.${NC}"
        exit 1
    else
        echo -e "${BLUE}Site Name\tDisplay Name${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"
        for site_file in "${CONFIG_DIR}"/*.conf; do
            source "${site_file}"
            printf "${GREEN}%-15s${NC}\t${GREEN}%s${NC}\n" "${SITE_NAME}" "${SITE_DISPLAY_NAME}"
        done
    fi
}

# Function to list available device templates
list_device_templates() {
    echo -e "\n${GREEN}Available device templates:${NC}"
    if [ -z "$(ls -A ${TEMPLATES_DIR}/*.yml.j2 2>/dev/null)" ]; then
        echo -e "${RED}No device templates found.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Template Name\tDevice Type${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    for template_file in "${TEMPLATES_DIR}"/*.yml.j2; do
        template_name=$(basename "${template_file}" .yml.j2)
        device_type=$(grep "^type:" "${template_file}" | head -1 | cut -d':' -f2- | xargs)
        printf "${GREEN}%-15s${NC}\t${GREEN}%s${NC}\n" "${template_name}" "${device_type}"
    done
}

# Function to list available example configurations
list_examples() {
    echo -e "\n${GREEN}Available example configurations:${NC}"
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

# Function to extract Jinja2 variables from a template
extract_template_variables() {
    local template_file=$1
    local tmp_dir="/tmp/template_vars_$$"
    mkdir -p "${tmp_dir}"

    # Extract all Jinja2 variables with default values
    grep -o "{{ [^}]*default([^}]*)" "${template_file}" | \
        sed 's/{{ \([a-zA-Z0-9_]*\) .*default(\([^)]*\)).*/\1: \2/' > "${tmp_dir}/vars.txt"

    # Format into a basic YAML structure
    {
        echo "# Configuration for $(basename ${template_file})"
        echo "template: $(basename ${template_file})"
        echo ""
        echo "# Basic settings"

        # Add each variable with its default value
        while IFS=: read -r var_name default_value; do
            # Clean up any quotes in the default value
            default_value=$(echo "$default_value" | sed "s/^['\"]//;s/['\"]$//")
            echo "${var_name}: ${default_value}"
        done < "${tmp_dir}/vars.txt"

        # Add some helpful comments for common templates
        if [[ $template_file == *"homeassistant"* ]]; then
            echo ""
            echo "# Optional integrations"
            echo "# sonos_integration: false"
            echo "# zwave_integration: false"
            echo "# mqtt_integration: true"
        elif [[ $template_file == *"nas"* ]]; then
            echo ""
            echo "# Service options"
            echo "# smb_enabled: true"
            echo "# nfs_enabled: true"
            echo "# web_ui_enabled: true"
        fi

        echo ""
        echo "# Security settings"
        echo "# allow_internet: true"
        echo "# allow_local_network: true"
        echo "# needs_dhcp_reservation: true"
    } > "${tmp_dir}/config.yml"

    cat "${tmp_dir}/config.yml"
    rm -rf "${tmp_dir}"
}

# Function to create a new device configuration from a template
create_device_config() {
    list_sites
    echo -e "\n${GREEN}Enter the short name of the site to add device to:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.conf" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        echo -e "${YELLOW}Please create the site first using scripts/create_site_config.sh${NC}"
        return 1
    fi

    # Load site config
    source "${CONFIG_DIR}/${site_name}.conf"

    # Choose how to create the device configuration
    echo -e "\n${GREEN}How would you like to create the device configuration?${NC}"
    echo -e "  1. Use an example configuration as a starting point"
    echo -e "  2. Create from scratch with a template"
    read -p "Select an option (1/2): " create_option

    case $create_option in
        1)
            list_examples
            echo -e "\n${GREEN}Enter the name of the example to use:${NC}"
            read example_name

            if [ ! -f "${EXAMPLES_DIR}/${example_name}.yml" ]; then
                echo -e "${RED}Error: Example '${example_name}' not found${NC}"
                return 1
            fi

            # Get the template name from the example
            template_name=$(grep "^template:" "${EXAMPLES_DIR}/${example_name}.yml" | cut -d':' -f2- | xargs)
            if [ ! -f "${TEMPLATES_DIR}/${template_name}" ]; then
                echo -e "${RED}Error: Template '${template_name}' referenced in example not found${NC}"
                return 1
            fi

            # Copy the example to a temporary file for editing
            tmp_config="/tmp/device_config_$$.yml"
            cp "${EXAMPLES_DIR}/${example_name}.yml" "${tmp_config}"

            # Replace any network_prefix references with the actual network prefix
            if grep -q "network_prefix" "${tmp_config}"; then
                sed -i "s|network_prefix|${NETWORK_PREFIX}|g" "${tmp_config}" 2>/dev/null || true
            fi
            ;;
        2)
            list_device_templates
            echo -e "\n${GREEN}Enter the name of the template to use:${NC}"
            read template_name

            if [ ! -f "${TEMPLATES_DIR}/${template_name}.yml.j2" ]; then
                echo -e "${RED}Error: Template '${template_name}' not found${NC}"
                return 1
            fi

            # Create a basic configuration by parsing the template
            tmp_config="/tmp/device_config_$$.yml"
            echo -e "\n${GREEN}Generating starter configuration from template...${NC}"
            extract_template_variables "${TEMPLATES_DIR}/${template_name}.yml.j2" > "${tmp_config}"

            # Replace any network_prefix references with the actual network prefix
            if grep -q "network_prefix" "${tmp_config}"; then
                sed -i "s|network_prefix|${NETWORK_PREFIX}|g" "${tmp_config}" 2>/dev/null || true
            fi
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            return 1
            ;;
    esac

    # Get device name
    echo -e "\n${GREEN}Enter a name for this device (e.g., living_room_nas):${NC}"
    read device_name

    # Validate device name - lowercase, no spaces, alphanumeric with underscores
    if [[ ! $device_name =~ ^[a-z0-9_]+$ ]]; then
        echo -e "${RED}Error: Device name must be lowercase, with no spaces or special characters (use underscores)${NC}"
        rm -f "${tmp_config}"
        return 1
    fi

    # Open editor for user to modify configuration
    echo -e "\n${YELLOW}Opening editor to modify device configuration...${NC}"
    if [ -n "$EDITOR" ]; then
        $EDITOR "${tmp_config}"
    elif command -v nano &> /dev/null; then
        nano "${tmp_config}"
    elif command -v vim &> /dev/null; then
        vim "${tmp_config}"
    else
        echo -e "${RED}No editor found. Set the EDITOR environment variable.${NC}"
        rm -f "${tmp_config}"
        return 1
    fi

    # Create site devices directory if it doesn't exist
    site_devices_dir="${SITE_DEVICES_DIR}/${site_name}"
    mkdir -p "${site_devices_dir}"

    # Create rendered directory if it doesn't exist
    mkdir -p "${RENDERED_DIR}"

    # Render the template
    echo -e "\n${GREEN}Rendering template...${NC}"
    ./scripts/render_template.py "${tmp_config}" -o "${RENDERED_DIR}/${device_name}.yml"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error rendering template. Check your configuration.${NC}"
        rm -f "${tmp_config}"
        return 1
    fi

    # Copy the template configuration to the site devices directory
    cp "${tmp_config}" "${site_devices_dir}/${device_name}.yml.config"

    # Get device data from rendered file
    device_type=$(yq e '.type' "${RENDERED_DIR}/${device_name}.yml")
    device_description=$(yq e '.description' "${RENDERED_DIR}/${device_name}.yml")
    device_vlan=$(yq e '.vlan' "${RENDERED_DIR}/${device_name}.yml")
    device_ip_suffix=$(yq e '.ip_suffix' "${RENDERED_DIR}/${device_name}.yml")
    device_needs_dhcp=$(yq e '.needs_dhcp_reservation' "${RENDERED_DIR}/${device_name}.yml")

    # Check if device needs MAC address for DHCP
    if [[ "$device_needs_dhcp" == "true" ]]; then
        echo -e "\n${GREEN}Enter MAC address for ${device_name} (format xx:xx:xx:xx:xx:xx):${NC}"
        read device_mac

        # Validate MAC address format
        if [[ ! $device_mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            echo -e "${RED}Error: Invalid MAC address format. Use xx:xx:xx:xx:xx:xx${NC}"
            rm -f "${tmp_config}"
            return 1
        fi
    fi

    # Create final device configuration file
    cat > "${site_devices_dir}/${device_name}.yml" <<EOL
# ${device_description} configuration for ${SITE_DISPLAY_NAME}
type: ${device_type}
name: ${device_name}
vlan: ${device_vlan}
ip_suffix: ${device_ip_suffix}
ip_address: ${NETWORK_PREFIX}.${device_vlan}.${device_ip_suffix}
EOL

    if [[ "$device_needs_dhcp" == "true" && -n "$device_mac" ]]; then
        echo "mac_address: ${device_mac}" >> "${site_devices_dir}/${device_name}.yml"
    fi

    # Update .env file with MAC address if needed
    if [[ "$device_needs_dhcp" == "true" && -n "$device_mac" ]]; then
        env_var_name="${site_name^^}_${device_name^^}_MAC"

        # Check if .env file exists
        if [ -f "${SCRIPT_DIR}/.env" ]; then
            # Check if variable already exists
            if grep -q "^${env_var_name}=" "${SCRIPT_DIR}/.env"; then
                # Update existing variable
                sed -i "s|^${env_var_name}=.*|${env_var_name}=\"${device_mac}\"|" "${SCRIPT_DIR}/.env"
            else
                # Add new variable
                echo -e "\n# ${device_description} for ${SITE_DISPLAY_NAME}" >> "${SCRIPT_DIR}/.env"
                echo "${env_var_name}=\"${device_mac}\"" >> "${SCRIPT_DIR}/.env"
            fi
        else
            # Create .env file
            echo -e "# Environment variables for ${SITE_DISPLAY_NAME}\n" > "${SCRIPT_DIR}/.env"
            echo "# ${device_description} for ${SITE_DISPLAY_NAME}" >> "${SCRIPT_DIR}/.env"
            echo "${env_var_name}=\"${device_mac}\"" >> "${SCRIPT_DIR}/.env"
        fi

        echo -e "${GREEN}Added MAC address to .env file as ${env_var_name}${NC}"
    fi

    # Clean up
    rm -f "${tmp_config}"

    # Update device listing in Ansible group vars
    update_site_devices "${site_name}"

    echo -e "\n${GREEN}Device ${device_name} (${device_description}) added to ${SITE_DISPLAY_NAME}!${NC}"
    echo -e "${GREEN}Template configuration saved to ${site_devices_dir}/${device_name}.yml.config${NC}"
    echo -e "${GREEN}Rendered device configuration saved to ${RENDERED_DIR}/${device_name}.yml${NC}"
    echo -e "${YELLOW}To apply these changes:${NC}"
    echo -e "1. Run the Ansible deployment for this site:"
    echo -e "   ansible-playbook ansible/master_playbook.yml --limit=${site_name} --tags=network,dhcp"
}

# Update site devices listing in Ansible group vars
update_site_devices() {
    local site_name=$1
    local site_devices_dir="${SITE_DEVICES_DIR}/${site_name}"

    if [ ! -d "${site_devices_dir}" ]; then
        echo -e "${YELLOW}No devices configured for ${site_name} yet.${NC}"
        return 0
    fi

    # Get site config
    source "${CONFIG_DIR}/${site_name}.conf"

    # Update Ansible group vars
    local group_vars_file="${ANSIBLE_GROUP_VARS_DIR}/${site_name}.yml"

    # Read existing file
    if [ -f "${group_vars_file}" ]; then
        # Make backup of current file
        cp "${group_vars_file}" "${group_vars_file}.bak"

        # Extract site_config section if it exists
        if grep -q "site_config:" "${group_vars_file}"; then
            yq e '.site_config' "${group_vars_file}" > /tmp/site_config_$$.yml
        fi
    fi

    # Create or update basic site config file
    if [ -f "/tmp/site_config_$$.yml" ]; then
        # Restore site_config section
        cat > "${group_vars_file}" <<EOL
---
# Site-specific variables for ${SITE_DISPLAY_NAME}
EOL
        cat /tmp/site_config_$$.yml >> "${group_vars_file}"
        rm -f /tmp/site_config_$$.yml
    else
        # Create new site config
        cat > "${group_vars_file}" <<EOL
---
# Site-specific variables for ${SITE_DISPLAY_NAME}
site_config:
  name: "${site_name}"
  display_name: "${SITE_DISPLAY_NAME}"
  network_prefix: "${NETWORK_PREFIX}"
  domain: "${DOMAIN}"
EOL
    fi

    # Start building devices section
    echo -e "\n# Device configurations for ${SITE_DISPLAY_NAME}" >> "${group_vars_file}"
    echo "site_devices:" >> "${group_vars_file}"

    # Add each device
    for device_file in "${site_devices_dir}"/*.yml; do
        [[ "${device_file}" == *".config" ]] && continue

        device_name=$(basename "${device_file}" .yml)
        device_type=$(yq e '.type' "${device_file}")
        device_vlan=$(yq e '.vlan' "${device_file}")
        device_ip_suffix=$(yq e '.ip_suffix' "${device_file}")
        device_ip="${NETWORK_PREFIX}.${device_vlan}.${device_ip_suffix}"

        echo "  ${device_name}:" >> "${group_vars_file}"
        echo "    type: ${device_type}" >> "${group_vars_file}"
        echo "    vlan: ${device_vlan}" >> "${group_vars_file}"
        echo "    ip_address: ${device_ip}" >> "${group_vars_file}"

        # Add MAC address if present
        if [[ -n "$(yq e '.mac_address' "${device_file}")" ]]; then
            device_mac=$(yq e '.mac_address' "${device_file}")
            echo "    mac_address: ${device_mac}" >> "${group_vars_file}"
        fi

        # Add the env var name for the MAC
        echo "    mac_var: \"${site_name^^}_${device_name^^}_MAC\"" >> "${group_vars_file}"
    done

    echo -e "${GREEN}Updated device configurations in ${group_vars_file}${NC}"
}

# Function to list devices for a site
list_devices() {
    list_sites
    echo -e "\n${GREEN}Enter the short name of the site:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.conf" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load site config
    source "${CONFIG_DIR}/${site_name}.conf"

    # List devices
    site_devices_dir="${SITE_DEVICES_DIR}/${site_name}"
    if [ ! -d "${site_devices_dir}" ] || [ -z "$(ls -A ${site_devices_dir}/*.yml 2>/dev/null)" ]; then
        echo -e "${RED}No devices configured for ${SITE_DISPLAY_NAME}${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Devices for ${SITE_DISPLAY_NAME}:${NC}"
    echo -e "${BLUE}Device Name\tType\tVLAN\tIP Address${NC}"
    echo -e "${BLUE}-----------------------------------------------------${NC}"

    for device_file in "${site_devices_dir}"/*.yml; do
        [[ "${device_file}" == *".config" ]] && continue

        device_name=$(basename "${device_file}" .yml)
        device_type=$(yq e '.type' "${device_file}")
        device_vlan=$(yq e '.vlan' "${device_file}")
        device_ip=$(yq e '.ip_address' "${device_file}")
        printf "${GREEN}%-15s${NC}\t${GREEN}%-10s${NC}\t${GREEN}%-5s${NC}\t${GREEN}%s${NC}\n" "${device_name}" "${device_type}" "${device_vlan}" "${device_ip}"
    done
}

# Function to remove a device
remove_device() {
    list_sites
    echo -e "\n${GREEN}Enter the short name of the site:${NC}"
    read site_name

    if [ ! -f "${CONFIG_DIR}/${site_name}.conf" ]; then
        echo -e "${RED}Error: Site '${site_name}' not found${NC}"
        return 1
    fi

    # Load site config
    source "${CONFIG_DIR}/${site_name}.conf"

    # List devices
    site_devices_dir="${SITE_DEVICES_DIR}/${site_name}"
    if [ ! -d "${site_devices_dir}" ] || [ -z "$(ls -A ${site_devices_dir}/*.yml 2>/dev/null)" ]; then
        echo -e "${RED}No devices configured for ${SITE_DISPLAY_NAME}${NC}"
        return 1
    fi

    echo -e "\n${GREEN}Devices for ${SITE_DISPLAY_NAME}:${NC}"
    echo -e "${BLUE}Device Name\tType\tIP Address${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"

    for device_file in "${site_devices_dir}"/*.yml; do
        [[ "${device_file}" == *".config" ]] && continue

        device_name=$(basename "${device_file}" .yml)
        device_type=$(yq e '.type' "${device_file}")
        device_ip=$(yq e '.ip_address' "${device_file}")
        printf "${GREEN}%-15s${NC}\t${GREEN}%-10s${NC}\t${GREEN}%s${NC}\n" "${device_name}" "${device_type}" "${device_ip}"
    done

    echo -e "\n${GREEN}Enter the name of the device to remove:${NC}"
    read device_name

    if [ ! -f "${site_devices_dir}/${device_name}.yml" ]; then
        echo -e "${RED}Error: Device '${device_name}' not found${NC}"
        return 1
    fi

    # Confirm deletion
    echo -e "${YELLOW}Are you sure you want to remove ${device_name} from ${SITE_DISPLAY_NAME}? (y/n)${NC}"
    read confirm

    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${GREEN}Operation cancelled.${NC}"
        return 0
    fi

    # Remove device files
    rm -f "${site_devices_dir}/${device_name}.yml"
    rm -f "${site_devices_dir}/${device_name}.yml.config"
    rm -f "${RENDERED_DIR}/${device_name}.yml"

    # Update site devices list
    update_site_devices "${site_name}"

    echo -e "${GREEN}Device ${device_name} removed from ${SITE_DISPLAY_NAME}${NC}"
    echo -e "${YELLOW}To apply these changes:${NC}"
    echo -e "1. Run the Ansible deployment for this site:"
    echo -e "   ansible-playbook ansible/master_playbook.yml --limit=${site_name} --tags=network,dhcp"
}

# Main menu
while true; do
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${GREEN}Device Configuration Tool Options:${NC}"
    echo -e "  1. Create a new device from template"
    echo -e "  2. List available device templates"
    echo -e "  3. List available example configurations"
    echo -e "  4. List configured devices for a site"
    echo -e "  5. Remove a device from a site"
    echo -e "  q. Quit"
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${YELLOW}Note: To create a new site, use the scripts/create_site_config.sh script first.${NC}"
    read -p "Select an option: " option

    case $option in
        1) create_device_config ;;
        2) list_device_templates ;;
        3) list_examples ;;
        4) list_devices ;;
        5) remove_device ;;
        q|Q) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
