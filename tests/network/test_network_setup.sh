#!/bin/bash

# Network Setup Test Script
# This script tests:
# 1. DHCP configuration for all VLANs
# 2. Network transition from initial DHCP to Management VLAN
# 3. OPNsense Tailscale integration across sites

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SITE_CONFIG_DIR="../config"
CREDENTIALS_DIR="../credentials"
ANSIBLE_DIR="../ansible"
TERRAFORM_DIR="../terraform"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is required but not installed"
        exit 1
    fi
}

# Check required commands
check_command "ansible"
check_command "terraform"
check_command "tailscale"
check_command "ping"
check_command "dig"

# Test DHCP Configuration
test_dhcp() {
    local site_name=$1
    local network_prefix=$2

    log_info "Testing DHCP configuration for $site_name"

    # Load site configuration
    if [ ! -f "$SITE_CONFIG_DIR/$site_name.yml" ]; then
        log_error "Site configuration not found: $SITE_CONFIG_DIR/$site_name.yml"
        return 1
    fi

    # Test each VLAN
    for vlan in 10 20 30 40 50; do
        log_info "Testing VLAN $vlan"

        # Get DHCP range from site config
        dhcp_start=$(yq e ".vlan_config.$vlan.dhcp_start" "$SITE_CONFIG_DIR/$site_name.yml")
        dhcp_end=$(yq e ".vlan_config.$vlan.dhcp_end" "$SITE_CONFIG_DIR/$site_name.yml")

        if [ -z "$dhcp_start" ] || [ -z "$dhcp_end" ]; then
            log_warn "No DHCP range configured for VLAN $vlan"
            continue
        fi

        # Test DNS resolution
        log_info "Testing DNS resolution for VLAN $vlan"
        if ! dig @$network_prefix.$vlan.1 $site_name.local &> /dev/null; then
            log_error "DNS resolution failed for VLAN $vlan"
            return 1
        fi

        # Test gateway connectivity
        log_info "Testing gateway connectivity for VLAN $vlan"
        if ! ping -c 1 $network_prefix.$vlan.1 &> /dev/null; then
            log_error "Gateway not reachable for VLAN $vlan"
            return 1
        fi
    done

    log_info "DHCP tests completed for $site_name"
    return 0
}

# Test Network Transition
test_network_transition() {
    local site_name=$1
    local old_ip=$2
    local new_ip=$3

    log_info "Testing network transition for $site_name"

    # Check transition file
    local transition_file="$CREDENTIALS_DIR/${site_name}_network_transition.txt"
    if [ ! -f "$transition_file" ]; then
        log_error "Network transition file not found: $transition_file"
        return 1
    fi

    # Verify old IP is still accessible
    log_info "Verifying old IP ($old_ip) is accessible"
    if ! ping -c 1 $old_ip &> /dev/null; then
        log_error "Old IP not accessible"
        return 1
    fi

    # Verify new IP is accessible
    log_info "Verifying new IP ($new_ip) is accessible"
    if ! ping -c 1 $new_ip &> /dev/null; then
        log_error "New IP not accessible"
        return 1
    fi

    # Verify .env file has both IPs
    if ! grep -q "${site_name^^}_PROXMOX_IP" .env || ! grep -q "${site_name^^}_MGMT_IP" .env; then
        log_error "Missing IP configuration in .env file"
        return 1
    fi

    log_info "Network transition tests completed for $site_name"
    return 0
}

# Test Tailscale Integration
test_tailscale() {
    local site1_name=$1
    local site2_name=$2
    local site1_prefix=$3
    local site2_prefix=$4

    log_info "Testing Tailscale integration between $site1_name and $site2_name"

    # Check Tailscale status
    if ! tailscale status &> /dev/null; then
        log_error "Tailscale not running"
        return 1
    fi

    # Test subnet routing
    log_info "Testing subnet routing"

    # Test Site 1 to Site 2
    log_info "Testing connectivity from $site1_name to $site2_name"
    if ! ping -c 1 $site2_prefix.10.100 &> /dev/null; then
        log_error "Cannot reach Site 2 NAS from Site 1"
        return 1
    fi

    # Test Site 2 to Site 1
    log_info "Testing connectivity from $site2_name to $site1_name"
    if ! ping -c 1 $site1_prefix.10.10 &> /dev/null; then
        log_error "Cannot reach Site 1 Home Assistant from Site 2"
        return 1
    fi

    # Test firewall rules
    log_info "Testing firewall rules"

    # Test SMB/NFS access
    if ! nc -z $site2_prefix.10.100 445 &> /dev/null; then
        log_error "SMB access to Site 2 NAS failed"
        return 1
    fi

    # Test Home Assistant access
    if ! nc -z $site1_prefix.10.10 8123 &> /dev/null; then
        log_error "Home Assistant access failed"
        return 1
    fi

    # Test Omada controller access
    if ! nc -z $site1_prefix.50.2 8088 &> /dev/null; then
        log_error "Omada controller access failed"
        return 1
    fi

    log_info "Tailscale integration tests completed"
    return 0
}

# Main test execution
main() {
    # Load site configurations
    if [ ! -f "$SITE_CONFIG_DIR/site1.yml" ] || [ ! -f "$SITE_CONFIG_DIR/site2.yml" ]; then
        log_error "Site configurations not found"
        exit 1
    fi

    # Get site information
    site1_name=$(yq e '.site_config.name' "$SITE_CONFIG_DIR/site1.yml")
    site2_name=$(yq e '.site_config.name' "$SITE_CONFIG_DIR/site2.yml")
    site1_prefix=$(yq e '.site_config.network_prefix' "$SITE_CONFIG_DIR/site1.yml")
    site2_prefix=$(yq e '.site_config.network_prefix' "$SITE_CONFIG_DIR/site2.yml")

    # Run DHCP tests
    log_info "Starting DHCP tests"
    test_dhcp "$site1_name" "$site1_prefix" || exit 1
    test_dhcp "$site2_name" "$site2_prefix" || exit 1

    # Run network transition tests
    log_info "Starting network transition tests"
    test_network_transition "$site1_name" "$site1_prefix.1.100" "$site1_prefix.50.10" || exit 1
    test_network_transition "$site2_name" "$site2_prefix.1.100" "$site2_prefix.50.10" || exit 1

    # Run Tailscale integration tests
    log_info "Starting Tailscale integration tests"
    test_tailscale "$site1_name" "$site2_name" "$site1_prefix" "$site2_prefix" || exit 1

    log_info "All tests completed successfully"
}

# Run main function
main
