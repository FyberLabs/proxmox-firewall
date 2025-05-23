#!/bin/bash

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "\e[34m[INFO]\e[0m $message" ;;
        "success") echo -e "\e[32m[SUCCESS]\e[0m $message" ;;
        "error") echo -e "\e[31m[ERROR]\e[0m $message" ;;
        "warning") echo -e "\e[33m[WARNING]\e[0m $message" ;;
    esac
}

# Run a test playbook
run_test() {
    local playbook=$1
    local site=$2
    print_status "info" "Running $playbook for site $site..."

    if ansible-playbook "ansible/playbooks/$playbook" --limit="$site"; then
        print_status "success" "$playbook completed successfully for $site"
        return 0
    else
        print_status "error" "$playbook failed for $site"
        return 1
    fi
}

# Main function
main() {
    local site=${1:-all}
    local failed_tests=0

    print_status "info" "Starting test suite for site: $site"

    # Run all test playbooks
    test_playbooks=(
        "test_network_connectivity.yml"
        "test_vpn_connectivity.yml"
        "test_dns_resolution.yml"
        "test_firewall_rules.yml"
        "test_vm_states.yml"
        "test_cross_site_connectivity.yml"
        "test_backup_verification.yml"
    )

    for playbook in "${test_playbooks[@]}"; do
        if ! run_test "$playbook" "$site"; then
            failed_tests=$((failed_tests + 1))
        fi
    done

    # Print summary
    if [ $failed_tests -eq 0 ]; then
        print_status "success" "All tests completed successfully!"
        exit 0
    else
        print_status "error" "$failed_tests test(s) failed"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
