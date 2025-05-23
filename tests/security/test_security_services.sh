#!/bin/bash

# Test script for Security Services (Pangolin SSO + Crowdsec)
# This script validates both the Terraform deployment and service functionality

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
LOG_FILE="$LOGS_DIR/security_services_test_$(date +%Y%m%d_%H%M%S).log"

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
check_command "docker"
check_command "docker-compose"
check_command "curl"
check_command "nc"
check_command "yq"
check_command "jq"

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

    # Check if security services module is enabled
    if ! grep -q 'security_services.*enabled.*=.*true' terraform.tfvars; then
        log_warn "Security services module is not enabled in terraform.tfvars"
    fi

    cd - > /dev/null || exit 1
    return 0
}

# Test VM deployment
test_vm_deployment() {
    local site_name=$1
    log_info "Testing security services VM deployment for site: $site_name"

    # Check if VM exists in Proxmox
    if ! qm list | grep -q "security-services-$site_name"; then
        log_error "Security services VM not found"
        return 1
    fi

    # Check VM status
    VM_STATUS=$(qm status "security-services-$site_name" | awk '{print $2}')
    if [ "$VM_STATUS" != "running" ]; then
        log_error "Security services VM is not running (status: $VM_STATUS)"
        return 1
    fi

    return 0
}

# Test Docker services
test_docker_services() {
    local site_name=$1
    log_info "Testing Docker services for site: $site_name"

    # Check if Docker is running
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "systemctl is-active docker" &> /dev/null; then
        log_error "Docker service is not running"
        return 1
    fi

    # Check Pangolin containers
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "docker ps | grep -q pangolin"; then
        log_error "Pangolin container is not running"
        return 1
    fi

    # Check Crowdsec containers
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "docker ps | grep -q crowdsec"; then
        log_error "Crowdsec container is not running"
        return 1
    fi

    return 0
}

# Test Pangolin SSO
test_pangolin_sso() {
    local site_name=$1
    log_info "Testing Pangolin SSO for site: $site_name"

    # Test HTTPS access
    if ! curl -s -k "https://sso.${DOMAIN}/health" &> /dev/null; then
        log_error "Cannot access Pangolin SSO health endpoint"
        return 1
    fi

    # Test database connection
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "docker exec pangolin_db pg_isready -U pangolin" &> /dev/null; then
        log_error "Pangolin database is not accessible"
        return 1
    fi

    return 0
}

# Test Crowdsec
test_crowdsec() {
    local site_name=$1
    log_info "Testing Crowdsec for site: $site_name"

    # Test HTTPS access
    if ! curl -s -k "https://crowdsec.${DOMAIN}/health" &> /dev/null; then
        log_error "Cannot access Crowdsec health endpoint"
        return 1
    fi

    # Test database connection
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "docker exec crowdsec_db pg_isready -U crowdsec" &> /dev/null; then
        log_error "Crowdsec database is not accessible"
        return 1
    fi

    # Test Crowdsec API
    if ! curl -s -k "https://crowdsec.${DOMAIN}/api/v1/health" &> /dev/null; then
        log_error "Crowdsec API is not accessible"
        return 1
    fi

    return 0
}

# Test SSL certificates
test_ssl_certificates() {
    local site_name=$1
    log_info "Testing SSL certificates for site: $site_name"

    # Check Pangolin certificate
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "test -f /etc/letsencrypt/live/sso.${DOMAIN}/fullchain.pem"; then
        log_error "Pangolin SSL certificate not found"
        return 1
    fi

    # Check Crowdsec certificate
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "test -f /etc/letsencrypt/live/crowdsec.${DOMAIN}/fullchain.pem"; then
        log_error "Crowdsec SSL certificate not found"
        return 1
    fi

    return 0
}

# Test firewall configuration
test_firewall() {
    local site_name=$1
    log_info "Testing firewall configuration for site: $site_name"

    # Check if UFW is active
    if ! ssh "security@${NETWORK_PREFIX}.50.8" "ufw status | grep -q 'Status: active'"; then
        log_error "UFW is not active"
        return 1
    fi

    # Test required ports
    local ports=(22 80 443 8080 8081)
    for port in "${ports[@]}"; do
        if ! ssh "security@${NETWORK_PREFIX}.50.8" "ufw status | grep -q '${port}/tcp.*ALLOW'"; then
            log_error "Port ${port} is not allowed in UFW"
            return 1
        fi
    done

    return 0
}

# Main test function
run_tests() {
    local site_name=$1

    log_info "Starting security services tests for site: $site_name"

    # Load site configuration
    if ! load_site_config "$site_name"; then
        log_error "Failed to load site configuration"
        return 1
    fi

    # Run tests
    local tests=(
        "test_terraform_config"
        "test_vm_deployment"
        "test_docker_services"
        "test_pangolin_sso"
        "test_crowdsec"
        "test_ssl_certificates"
        "test_firewall"
    )

    local failed=0
    for test in "${tests[@]}"; do
        if ! "$test" "$site_name"; then
            log_error "Test failed: $test"
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        log_info "All security services tests passed for site: $site_name"
    else
        log_error "Some security services tests failed for site: $site_name"
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
        log_info "All security services tests completed successfully"
        exit 0
    else
        log_error "Some security services tests failed"
        exit 1
    fi
}

# Run main function
main
