#!/bin/bash
set -euo pipefail

# Docker Testing Framework - Full Deployment Test
# Quick start script for testing complete Proxmox firewall deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

main() {
    log_info "Starting Full Deployment Test"
    log_info "This will test the complete Proxmox firewall deployment process"

    # Run the comprehensive test suite
    "$SCRIPT_DIR/run-tests.sh" \
        --suite integration \
        --parallel true \
        --clean \
        --debug false

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Full deployment test completed successfully!"
        log_info "The Proxmox firewall deployment is ready for production use."
    else
        log_error "Full deployment test failed. Please check the logs and fix any issues."
    fi

    exit $exit_code
}

main "$@"
