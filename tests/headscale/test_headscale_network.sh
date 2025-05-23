#!/bin/bash

# Test script for Headscale network configuration
# This script validates both the Terraform deployment and network connectivity

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration directories
SITE_CONFIG_DIR="config/sites"
CREDS_DIR="config/credentials"
TERRAFORM_DIR="terraform"
LOGS_DIR="logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Log file with timestamp
LOG_FILE="$LOGS_DIR/headscale_test_$(date +%Y%m%d_%H%M%S).log"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command '$1' not found"
        exit 1
    fi
}

# Check required commands
check_command "terraform"
check_command "headscale"
check_command "ping"
check_command "nc"
check_command "yq"
check_command "curl"

# Load site configurations
load_site_config() {
    local site_name=$1
    local config_file="$SITE_CONFIG_DIR/$site_name.yaml"

    if [ ! -f "$config_file" ]; then
        log_error "Site configuration file not found: $config_file"
        return 1
    fi

    # Load configuration using yq
    NETWORK_PREFIX=$(yq eval '.network.prefix' "$config_file")
    DOMAIN=$(yq eval '.network.domain' "$config_file")
    SITE_DISPLAY_NAME=$(yq eval '.site.display_name' "$config_file")

    return 0
}

# Test Terraform configuration
test_terraform_config() {
    local site_name=$1
    log_info "Testing Terraform configuration for site: $site_name"

    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found"
        return 1
    fi

    # Validate terraform configuration
    cd "$TERRAFORM_DIR" || exit 1
    if ! terraform validate; then
        log_error "Terraform configuration validation failed"
        return 1
    fi

    # Check if Headscale module is enabled
    if ! grep -q 'headscale.*enabled.*=.*true' terraform.tfvars; then
        log_warn "Headscale module is not enabled in terraform.tfvars"
    fi

    cd - > /dev/null || exit 1
    return 0
}

# Test Headscale VM deployment
test_headscale_vm() {
    local site_name=$1
    log_info "Testing Headscale VM deployment for site: $site_name"

    # Check if VM exists in Proxmox
    if ! qm list | grep -q "headscale-server-$site_name"; then
        log_error "Headscale server VM not found"
        return 1
    fi

    # Check VM status
    VM_STATUS=$(qm status "headscale-server-$site_name" | awk '{print $2}')
    if [ "$VM_STATUS" != "running" ]; then
        log_error "Headscale server VM is not running (status: $VM_STATUS)"
        return 1
    fi

    return 0
}

# Test Headscale service
test_headscale_service() {
    local site_name=$1
    log_info "Testing Headscale service for site: $site_name"

    # Check Headscale service status
    if ! ssh "headscale@${NETWORK_PREFIX}.50.7" "sudo systemctl is-active headscale" &> /dev/null; then
        log_error "Headscale service is not running"
        return 1
    fi

    # Test Headscale API
    if ! curl -s "https://headscale.${DOMAIN}:50443/health" &> /dev/null; then
        log_error "Headscale API is not accessible"
        return 1
    fi

    return 0
}

# Test Headscale connectivity
test_headscale_connectivity() {
    local site_name=$1
    log_info "Testing Headscale connectivity for site: $site_name"

    # Test connectivity to Headscale server
    SERVER_IP="${NETWORK_PREFIX}.50.7"
    if ! ping -c 1 "$SERVER_IP" &> /dev/null; then
        log_error "Cannot ping Headscale server at $SERVER_IP"
        return 1
    fi

    # Test SSH access
    if ! nc -z "$SERVER_IP" 22 &> /dev/null; then
        log_error "Cannot connect to SSH on Headscale server"
        return 1
    fi

    return 0
}

# Test DERP server
test_derp_server() {
    local site_name=$1
    log_info "Testing DERP server for site: $site_name"

    # Test STUN server
    if ! nc -z "${NETWORK_PREFIX}.50.7" 3478 &> /dev/null; then
        log_error "STUN server is not accessible"
        return 1
    fi

    # Test DERP server
    if ! curl -s "https://headscale.${DOMAIN}:50443/derp" &> /dev/null; then
        log_error "DERP server is not accessible"
        return 1
    fi

    return 0
}

# Test Headscale nodes
test_headscale_nodes() {
    local site_name=$1
    log_info "Testing Headscale nodes for site: $site_name"

    # Check if nodes are registered
    if ! ssh "headscale@${NETWORK_PREFIX}.50.7" "sudo headscale nodes list" | grep -q "online"; then
        log_error "No online nodes found"
        return 1
    fi

    return 0
}

# Main test function
run_tests() {
    local site_name=$1

    log_info "Starting Headscale network tests for site: $site_name"

    # Load site configuration
    if ! load_site_config "$site_name"; then
        log_error "Failed to load site configuration"
        return 1
    fi

    # Run tests
    local tests=(
        "test_terraform_config"
        "test_headscale_vm"
        "test_headscale_service"
        "test_headscale_connectivity"
        "test_derp_server"
        "test_headscale_nodes"
    )

    local failed=0
    for test in "${tests[@]}"; do
        if ! "$test" "$site_name"; then
            log_error "Test failed: $test"
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        log_info "All Headscale network tests passed for site: $site_name"
    else
        log_error "Some Headscale network tests failed for site: $site_name"
    fi

    return $failed
}

# Run tests for all sites
main() {
    local failed=0

    # Get list of sites
    for site_config in "$SITE_CONFIG_DIR"/*.yaml; do
        site_name=$(basename "$site_config" .yaml)
        if ! run_tests "$site_name"; then
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        log_info "All Headscale network tests completed successfully"
        exit 0
    else
        log_error "Some Headscale network tests failed"
        exit 1
    fi
}

# Run main function
main
