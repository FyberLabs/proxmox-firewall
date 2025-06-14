#!/bin/bash
# Refactored: Use PROXMOX_FW_CONFIG_ROOT for config path, supporting submodule usage.
# Set via environment, or auto-detect below.

# Auto-detect config root
if [ -z "$PROXMOX_FW_CONFIG_ROOT" ]; then
  if [ -d "./config" ]; then
    export PROXMOX_FW_CONFIG_ROOT="./config"
  elif [ -d "vendor/proxmox-firewall/config" ]; then
    export PROXMOX_FW_CONFIG_ROOT="vendor/proxmox-firewall/config"
  else
    echo "ERROR: Could not find config root directory." >&2
    exit 1
  fi
fi

# Use $PROXMOX_FW_CONFIG_ROOT in all config path references below

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Function to print status messages
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "\e[34mℹ️  $message\e[0m" ;;
        "success") echo -e "\e[32m✅ $message\e[0m" ;;
        "error") echo -e "\e[31m❌ $message\e[0m" ;;
        "warning") echo -e "\e[33m⚠️  $message\e[0m" ;;
    esac
}

# Function to validate CPU configuration
validate_cpu() {
    local cpu_type=$1
    local cores=$2
    local threads=$3

    # Validate CPU type
    if [[ ! "$cpu_type" =~ ^(n100|n305)$ ]]; then
        print_status "error" "Invalid CPU type: $cpu_type. Must be n100 or n305"
        return 1
    fi

    # Validate cores and threads
    if [[ ! "$cores" =~ ^[0-9]+$ ]] || [[ ! "$threads" =~ ^[0-9]+$ ]]; then
        print_status "error" "Invalid CPU cores or threads configuration"
        return 1
    fi

    # Check against hardware limits
    if [ "$cpu_type" == "n100" ] && [ "$cores" -gt 4 ]; then
        print_status "error" "N100 CPU supports maximum 4 cores"
        return 1
    fi

    if [ "$cpu_type" == "n305" ] && [ "$cores" -gt 8 ]; then
        print_status "error" "N305 CPU supports maximum 8 cores"
        return 1
    fi

    print_status "success" "CPU configuration validated"
    return 0
}

# Function to validate memory configuration
validate_memory() {
    local total=$1
    local vm_allocation=$2

    # Validate total memory
    if [[ ! "$total" =~ ^[0-9]+gb$ ]]; then
        print_status "error" "Invalid total memory format: $total"
        return 1
    fi

    # Extract numeric value
    local total_gb=${total%gb}
    if [ "$total_gb" -lt 8 ] || [ "$total_gb" -gt 16 ]; then
        print_status "error" "Total memory must be between 8GB and 16GB"
        return 1
    fi

    # Validate VM allocations
    local total_allocated=0
    for vm in "${!vm_allocation[@]}"; do
        local vm_mem=${vm_allocation[$vm]}
        if [[ ! "$vm_mem" =~ ^[0-9]+gb$ ]]; then
            print_status "error" "Invalid memory allocation for $vm: $vm_mem"
            return 1
        fi
        total_allocated=$((total_allocated + ${vm_mem%gb}))
    done

    if [ "$total_allocated" -gt "$total_gb" ]; then
        print_status "error" "Total VM memory allocation ($total_allocated GB) exceeds total memory ($total_gb GB)"
        return 1
    fi

    print_status "success" "Memory configuration validated"
    return 0
}

# Function to validate storage configuration
validate_storage() {
    local type=$1
    local size=$2
    local allocation=$3

    # Validate storage type
    if [[ ! "$type" =~ ^(ssd|nvme)$ ]]; then
        print_status "error" "Invalid storage type: $type"
        return 1
    fi

    # Validate size
    if [[ ! "$size" =~ ^[0-9]+gb$ ]]; then
        print_status "error" "Invalid storage size format: $size"
        return 1
    fi

    # Extract numeric value
    local size_gb=${size%gb}
    if [ "$size_gb" -lt 128 ] || [ "$size_gb" -gt 512 ]; then
        print_status "error" "Storage size must be between 128GB and 512GB"
        return 1
    fi

    # Validate allocation
    local total_allocated=0
    for partition in "${!allocation[@]}"; do
        local part_size=${allocation[$partition]}
        if [[ ! "$part_size" =~ ^[0-9]+gb$ ]]; then
            print_status "error" "Invalid allocation for $partition: $part_size"
            return 1
        fi
        total_allocated=$((total_allocated + ${part_size%gb}))
    done

    if [ "$total_allocated" -gt "$size_gb" ]; then
        print_status "error" "Total allocation ($total_allocated GB) exceeds storage size ($size_gb GB)"
        return 1
    fi

    print_status "success" "Storage configuration validated"
    return 0
}

# Function to validate network configuration
validate_network() {
    local interfaces=$1
    local vlans=$2
    local bridges=$3

    # Validate interfaces
    for interface in "${interfaces[@]}"; do
        if [[ ! "${interface[type]}" =~ ^(2\.5gbe|10gbe)$ ]]; then
            print_status "error" "Invalid interface type for ${interface[name]}: ${interface[type]}"
            return 1
        fi

        if [[ ! "${interface[role]}" =~ ^(wan|wan_backup|lan|cameras)$ ]]; then
            print_status "error" "Invalid interface role for ${interface[name]}: ${interface[role]}"
            return 1
        fi
    done

    # Validate VLANs
    for vlan in "${vlans[@]}"; do
        if [[ ! "${vlan[id]}" =~ ^[0-9]+$ ]] || [ "${vlan[id]}" -lt 1 ] || [ "${vlan[id]}" -gt 4094 ]; then
            print_status "error" "Invalid VLAN ID: ${vlan[id]}"
            return 1
        fi

        if [[ ! "${vlan[subnet]}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            print_status "error" "Invalid subnet for VLAN ${vlan[id]}: ${vlan[subnet]}"
            return 1
        fi
    done

    # Validate bridges
    for bridge in "${bridges[@]}"; do
        if [[ ! "${bridge[name]}" =~ ^vmbr[0-9]+$ ]]; then
            print_status "error" "Invalid bridge name: ${bridge[name]}"
            return 1
        fi

        # Check if bridge interface exists
        if ! grep -q "${bridge[interface]}" /proc/net/dev; then
            print_status "error" "Bridge interface ${bridge[interface]} does not exist"
            return 1
        fi
    done

    print_status "success" "Network configuration validated"
    return 0
}

# Main function
main() {
    local site_config=$1
    if [ ! -f "$site_config" ]; then
        print_status "error" "Site configuration file not found: $site_config"
        exit 1
    fi

    # Load site configuration
    source "$site_config"

    # Validate hardware configuration
    print_status "info" "Validating hardware configuration..."

    validate_cpu "$hardware[cpu][type]" "$hardware[cpu][cores]" "$hardware[cpu][threads]" || exit 1
    validate_memory "$hardware[memory][total]" "$hardware[memory][vm_allocation]" || exit 1
    validate_storage "$hardware[storage][type]" "$hardware[storage][size]" "$hardware[storage][allocation]" || exit 1
    validate_network "$hardware[network][interfaces]" "$hardware[network][vlans]" "$hardware[network][bridges]" || exit 1

    print_status "success" "All hardware configurations validated successfully"
}

# Check if site config file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <site_config_file>"
    exit 1
fi

main "$1"
