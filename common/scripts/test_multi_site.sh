#!/bin/bash
set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS") echo -e "\e[32m✓ $message\e[0m" ;;
        "FAIL") echo -e "\e[31m✗ $message\e[0m" ;;
        "INFO") echo -e "\e[34mℹ $message\e[0m" ;;
        *) echo "$message" ;;
    esac
}

# Function to run a test and check its result
run_test() {
    local test_name=$1
    local test_command=$2
    print_status "INFO" "Running $test_name..."

    if eval "$test_command"; then
        print_status "PASS" "$test_name completed successfully"
        return 0
    else
        print_status "FAIL" "$test_name failed"
        return 1
    fi
}

# Function to validate site configuration
validate_site_config() {
    local site=$1
    print_status "INFO" "Validating configuration for site: $site"

    # Check if site config exists
    if [ ! -f "config/$site.conf" ]; then
        print_status "FAIL" "Site configuration file not found: config/$site.conf"
        return 1
    fi

    # Check if network config exists
    if [ ! -f "config/network/$site.yml" ]; then
        print_status "FAIL" "Network configuration file not found: config/network/$site.yml"
        return 1
    fi

    # Check if hardware config exists
    if [ ! -f "config/hardware/$site.yml" ]; then
        print_status "FAIL" "Hardware configuration file not found: config/hardware/$site.yml"
        return 1
    fi

    print_status "PASS" "Site configuration validation passed"
    return 0
}

# Main test function
run_site_tests() {
    local site=$1
    local failed_tests=0

    print_status "INFO" "Starting tests for site: $site"

    # Validate site configuration
    if ! validate_site_config "$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run network connectivity tests
    if ! run_test "Network Connectivity" "ansible-playbook ansible/playbooks/test_network_connectivity.yml --limit=$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run VPN connectivity tests
    if ! run_test "VPN Connectivity" "ansible-playbook ansible/playbooks/test_vpn_connectivity.yml --limit=$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run DNS resolution tests
    if ! run_test "DNS Resolution" "ansible-playbook ansible/playbooks/test_dns_resolution.yml --limit=$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run firewall validation tests
    if ! run_test "Firewall Validation" "ansible-playbook ansible/playbooks/test_firewall_rules.yml --limit=$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run VM state tests
    if ! run_test "VM State" "ansible-playbook ansible/playbooks/test_vm_states.yml --limit=$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run backup verification tests
    if ! run_test "Backup Verification" "ansible-playbook ansible/playbooks/verify_backups.yml --limit=$site"; then
        failed_tests=$((failed_tests + 1))
    fi

    # Run cross-site connectivity tests if multiple sites exist
    if [ -f "config/global_network.yml" ]; then
        if ! run_test "Cross-Site Connectivity" "ansible-playbook ansible/playbooks/test_cross_site_connectivity.yml --limit=$site"; then
            failed_tests=$((failed_tests + 1))
        fi
    fi

    return $failed_tests
}

# Main execution
main() {
    local target_site=$1
    local total_failed=0

    # Check if specific site was provided
    if [ -n "$target_site" ]; then
        if ! run_site_tests "$target_site"; then
            total_failed=$((total_failed + 1))
        fi
    else
        # Run tests for all sites
        for site_config in config/*.conf; do
            if [ -f "$site_config" ]; then
                site_name=$(basename "$site_config" .conf)
                if ! run_site_tests "$site_name"; then
                    total_failed=$((total_failed + 1))
                fi
            fi
        done
    fi

    # Print summary
    echo
    print_status "INFO" "Test Summary:"
    if [ $total_failed -eq 0 ]; then
        print_status "PASS" "All tests completed successfully"
        exit 0
    else
        print_status "FAIL" "$total_failed test(s) failed"
        exit 1
    fi
}

# Run main function with provided arguments
main "$@"
