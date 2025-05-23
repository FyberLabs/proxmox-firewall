#!/bin/bash

# System Health Monitoring Script
# This script performs periodic health checks on the Proxmox firewall setup
# Can be run via cron or systemd timer

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
LOG_DIR="../logs"
ALERT_EMAIL="admin@example.com"  # Configure this

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Log file with timestamp
LOG_FILE="$LOG_DIR/health_check_$(date +%Y%m%d_%H%M%S).log"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local subject="$1"
    local message="$2"
    echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
}

# Check required commands
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is required but not installed"
        exit 1
    fi
}

# Check OPNsense Health
check_opnsense() {
    local site_name=$1
    local mgmt_ip=$2

    log_info "Checking OPNsense health for $site_name"

    # Check OPNsense service status
    if ! ssh root@$mgmt_ip "opnsense-version" &> /dev/null; then
        log_error "OPNsense service not responding on $site_name"
        send_alert "OPNsense Service Alert" "OPNsense service not responding on $site_name"
        return 1
    fi

    # Check required packages
    local required_packages=("os-tailscale" "os-theme-vicuna" "os-wireguard")
    for package in "${required_packages[@]}"; do
        if ! ssh root@$mgmt_ip "pkg info $package" &> /dev/null; then
            log_warn "Package $package not installed on $site_name"
        fi
    done

    # Check firewall rules
    if ! ssh root@$mgmt_ip "pfctl -s rules" &> /dev/null; then
        log_error "Firewall rules not properly loaded on $site_name"
        send_alert "Firewall Rules Alert" "Firewall rules not properly loaded on $site_name"
        return 1
    fi

    # Check DNS resolver
    if ! ssh root@$mgmt_ip "unbound-control status" &> /dev/null; then
        log_error "DNS resolver not running on $site_name"
        send_alert "DNS Resolver Alert" "DNS resolver not running on $site_name"
        return 1
    fi

    # Check DHCP server
    if ! ssh root@$mgmt_ip "dhcpd -t" &> /dev/null; then
        log_error "DHCP server configuration error on $site_name"
        send_alert "DHCP Server Alert" "DHCP server configuration error on $site_name"
        return 1
    fi

    log_info "OPNsense health check completed for $site_name"
    return 0
}

# Check Proxmox VM States
check_vm_states() {
    local site_name=$1
    local proxmox_ip=$2

    log_info "Checking VM states for $site_name"

    # Get list of expected VMs from site config
    local vms=$(yq e '.vms[].name' "$SITE_CONFIG_DIR/$site_name.yml")

    for vm in $vms; do
        # Check VM status
        if ! ssh root@$proxmox_ip "qm status $vm" | grep -q "running"; then
            log_error "VM $vm not running on $site_name"
            send_alert "VM Status Alert" "VM $vm not running on $site_name"
            return 1
        fi

        # Check VM resources
        if ! ssh root@$proxmox_ip "qm config $vm" | grep -q "memory"; then
            log_warn "VM $vm resource configuration issue on $site_name"
        fi
    done

    log_info "VM state check completed for $site_name"
    return 0
}

# Check Network Connectivity
check_network() {
    local site_name=$1
    local mgmt_ip=$2
    local network_prefix=$3

    log_info "Checking network connectivity for $site_name"

    # Check WAN connectivity
    if ! ssh root@$mgmt_ip "ping -c 1 8.8.8.8" &> /dev/null; then
        log_error "WAN connectivity issue on $site_name"
        send_alert "WAN Connectivity Alert" "WAN connectivity issue on $site_name"
        return 1
    fi

    # Check VLAN routing
    for vlan in 10 20 30 40 50; do
        if ! ssh root@$mgmt_ip "ping -c 1 $network_prefix.$vlan.1" &> /dev/null; then
            log_error "VLAN $vlan routing issue on $site_name"
            send_alert "VLAN Routing Alert" "VLAN $vlan routing issue on $site_name"
            return 1
        fi
    done

    # Check Tailscale
    if ! ssh root@$mgmt_ip "tailscale status" &> /dev/null; then
        log_error "Tailscale not running on $site_name"
        send_alert "Tailscale Alert" "Tailscale not running on $site_name"
        return 1
    fi

    log_info "Network connectivity check completed for $site_name"
    return 0
}

# Check Security and Monitoring
check_security() {
    local site_name=$1
    local mgmt_ip=$2

    log_info "Checking security and monitoring for $site_name"

    # Check Zeek logs
    if ! ssh root@$mgmt_ip "ls /var/log/zeek/current" &> /dev/null; then
        log_error "Zeek logging issue on $site_name"
        send_alert "Zeek Logging Alert" "Zeek logging issue on $site_name"
        return 1
    fi

    # Check Suricata
    if ! ssh root@$mgmt_ip "suricata -T" &> /dev/null; then
        log_error "Suricata configuration issue on $site_name"
        send_alert "Suricata Alert" "Suricata configuration issue on $site_name"
        return 1
    fi

    # Check log rotation
    if ! ssh root@$mgmt_ip "logrotate -d /etc/logrotate.conf" &> /dev/null; then
        log_warn "Log rotation configuration issue on $site_name"
    fi

    log_info "Security and monitoring check completed for $site_name"
    return 0
}

# Main monitoring function
main() {
    log_info "Starting system health check"

    # Load site configurations
    if [ ! -f "$SITE_CONFIG_DIR/site1.yml" ] || [ ! -f "$SITE_CONFIG_DIR/site2.yml" ]; then
        log_error "Site configurations not found"
        exit 1
    fi

    # Check each site
    for site in site1 site2; do
        site_name=$(yq e '.site_config.name' "$SITE_CONFIG_DIR/$site.yml")
        mgmt_ip=$(yq e '.site_config.mgmt_ip' "$SITE_CONFIG_DIR/$site.yml")
        proxmox_ip=$(yq e '.site_config.proxmox_ip' "$SITE_CONFIG_DIR/$site.yml")
        network_prefix=$(yq e '.site_config.network_prefix' "$SITE_CONFIG_DIR/$site.yml")

        # Run all checks
        check_opnsense "$site_name" "$mgmt_ip" || continue
        check_vm_states "$site_name" "$proxmox_ip" || continue
        check_network "$site_name" "$mgmt_ip" "$network_prefix" || continue
        check_security "$site_name" "$mgmt_ip" || continue
    done

    log_info "System health check completed"
}

# Run main function
main
