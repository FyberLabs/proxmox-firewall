#!/bin/bash
# Comprehensive Test Runner for Proxmox Firewall
# Runs unit tests, integration tests, and CI/CD validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test configuration
RUN_UNIT_TESTS=true
RUN_INTEGRATION_TESTS=true
RUN_CICD_TESTS=true
VERBOSE=false
CLEANUP_AFTER=true
PARALLEL_TESTS=false

# Test results
UNIT_TEST_RESULTS=""
INTEGRATION_TEST_RESULTS=""
CICD_TEST_RESULTS=""
OVERALL_SUCCESS=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --unit-only         Run only unit tests"
    echo "  --integration-only  Run only integration tests"
    echo "  --cicd-only         Run only CI/CD tests"
    echo "  --no-cleanup        Don't cleanup Docker containers after tests"
    echo "  --parallel          Run tests in parallel where possible"
    echo "  -v, --verbose       Verbose output"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                  # Run all tests"
    echo "  $0 --unit-only     # Run only unit tests (fast)"
    echo "  $0 --integration-only --verbose  # Run integration tests with verbose output"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            RUN_INTEGRATION_TESTS=false
            RUN_CICD_TESTS=false
            shift
            ;;
        --integration-only)
            RUN_UNIT_TESTS=false
            RUN_CICD_TESTS=false
            shift
            ;;
        --cicd-only)
            RUN_UNIT_TESTS=false
            RUN_INTEGRATION_TESTS=false
            shift
            ;;
        --no-cleanup)
            CLEANUP_AFTER=false
            shift
            ;;
        --parallel)
            PARALLEL_TESTS=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"

    local missing_tools=()

    # Check for required tools
    if ! command -v python3 >/dev/null 2>&1; then
        missing_tools+=("python3")
    fi

    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi

    if ! command -v docker-compose >/dev/null 2>&1; then
        missing_tools+=("docker-compose")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi

    # Check Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi

    # Check Python packages
    if ! python3 -c "import yaml, requests" >/dev/null 2>&1; then
        log_warning "Some Python packages may be missing. Installing..."
        pip3 install pyyaml requests >/dev/null 2>&1 || true
    fi

    log_success "Prerequisites check passed"
}

# Setup test environment
setup_test_environment() {
    log_section "Setting Up Test Environment"

    cd "$SCRIPT_DIR"

    # Create test directories
    mkdir -p test-results logs reports

    # Clean up any existing test containers
    if [[ "$CLEANUP_AFTER" == "true" ]]; then
        log_info "Cleaning up existing test containers..."
        docker-compose down >/dev/null 2>&1 || true
    fi

    # Set environment variables for tests
    export TEST_PROJECT_ROOT="$PROJECT_ROOT"
    export TEST_SCRIPT_DIR="$SCRIPT_DIR"
    export TEST_VERBOSE="$VERBOSE"

    log_success "Test environment setup complete"
}

# Run unit tests
run_unit_tests() {
    log_section "Running Unit Tests"

    local unit_test_start=$(date +%s)
    local unit_test_success=true

    cd "$PROJECT_ROOT"

    # Run Python unit tests
    if [[ -f "tests/test_config_validation.py" ]]; then
        log_info "Running configuration validation tests..."
        if python3 -m pytest tests/test_config_validation.py -v 2>&1 | tee "$SCRIPT_DIR/logs/unit_tests.log"; then
            log_success "Configuration validation tests passed"
        else
            log_error "Configuration validation tests failed"
            unit_test_success=false
        fi
    fi

    # Run YAML syntax validation
    log_info "Running YAML syntax validation..."
    local yaml_errors=0

    # Check all YAML files in config directory
    if [[ -d "config" ]]; then
        while IFS= read -r -d '' yaml_file; do
            if ! python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
                log_error "YAML syntax error in: $yaml_file"
                ((yaml_errors++))
            fi
        done < <(find config -name "*.yml" -print0)
    fi

    # Check test framework YAML files
    while IFS= read -r -d '' yaml_file; do
        if ! python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            log_error "YAML syntax error in: $yaml_file"
            ((yaml_errors++))
        fi
    done < <(find "$SCRIPT_DIR" -name "*.yml" -print0)

    if [[ $yaml_errors -eq 0 ]]; then
        log_success "All YAML files have valid syntax"
    else
        log_error "Found $yaml_errors YAML syntax errors"
        unit_test_success=false
    fi

    # Run shell script syntax checks
    log_info "Running shell script syntax validation..."
    local script_errors=0

    while IFS= read -r -d '' script_file; do
        if ! bash -n "$script_file" 2>/dev/null; then
            log_error "Shell syntax error in: $script_file"
            ((script_errors++))
        fi
    done < <(find . -name "*.sh" -print0)

    if [[ $script_errors -eq 0 ]]; then
        log_success "All shell scripts have valid syntax"
    else
        log_error "Found $script_errors shell script syntax errors"
        unit_test_success=false
    fi

    local unit_test_end=$(date +%s)
    local unit_test_duration=$((unit_test_end - unit_test_start))

    if [[ "$unit_test_success" == "true" ]]; then
        UNIT_TEST_RESULTS="✓ PASSED (${unit_test_duration}s)"
        log_success "Unit tests completed successfully in ${unit_test_duration}s"
    else
        UNIT_TEST_RESULTS="✗ FAILED (${unit_test_duration}s)"
        log_error "Unit tests failed in ${unit_test_duration}s"
        OVERALL_SUCCESS=false
    fi
}

# Start mock services
start_mock_services() {
    log_info "Starting mock services..."

    cd "$SCRIPT_DIR"

    # Check if Docker Compose file exists - prefer minimal for CI/CD
    local compose_file="compose/docker-compose.minimal.yml"
    if [[ ! -f "$compose_file" ]]; then
        compose_file="compose/docker-compose.yml"
        if [[ ! -f "$compose_file" ]]; then
            log_error "Docker Compose file not found: $compose_file"
            return 1
        fi
    fi

    # Start Docker Compose services
    if [[ "$VERBOSE" == "true" ]]; then
        docker compose -f "$compose_file" up -d
    else
        docker compose -f "$compose_file" up -d >/dev/null 2>&1
    fi

        # Wait for services to be ready
    log_info "Waiting for mock services to be ready..."
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        # Check if proxmox-mock is ready (main service for testing)
        if curl -s http://localhost:8006/health >/dev/null 2>&1; then
            log_success "Mock services are ready"
            return 0
        fi

        ((attempt++))
        sleep 2
    done

    log_error "Mock services failed to start within timeout"
    docker compose -f "$compose_file" logs
    return 1
}

# Run integration tests
run_integration_tests() {
    log_section "Running Integration Tests"

    local integration_test_start=$(date +%s)
    local integration_test_success=true

    cd "$SCRIPT_DIR"

    # Start mock services
    if ! start_mock_services; then
        INTEGRATION_TEST_RESULTS="✗ FAILED (mock services)"
        OVERALL_SUCCESS=false
        return 1
    fi

    # Run Python integration tests
    log_info "Running Python integration tests..."
    if python3 test_integration.py 2>&1 | tee logs/integration_tests.log; then
        log_success "Python integration tests passed"
    else
        log_error "Python integration tests failed"
        integration_test_success=false
    fi

    # Run Ansible syntax checks if available
    if command -v ansible-playbook >/dev/null 2>&1; then
        log_info "Running Ansible syntax validation..."
        local ansible_errors=0

        while IFS= read -r -d '' playbook; do
            # Skip non-playbook files like requirements.yml, group_vars, host_vars, etc.
            if [[ "$playbook" == *"requirements.yml" ]] || [[ "$playbook" == *"group_vars"* ]] || [[ "$playbook" == *"host_vars"* ]]; then
                continue
            fi
            if ! ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
                log_error "Ansible syntax error in: $playbook"
                ((ansible_errors++))
            fi
        done < <(find "$PROJECT_ROOT/deployment" -name "*.yml" -print0 2>/dev/null || true)

        if [[ $ansible_errors -eq 0 ]]; then
            log_success "All Ansible playbooks have valid syntax"
        else
            log_error "Found $ansible_errors Ansible syntax errors"
            integration_test_success=false
        fi
    else
        log_warning "Ansible not available, skipping Ansible syntax checks"
    fi

    # Test Docker Compose configurations
    log_info "Validating Docker Compose configurations..."
    local compose_errors=0

    while IFS= read -r -d '' compose_file; do
        if ! docker compose -f "$compose_file" config >/dev/null 2>&1; then
            log_error "Docker Compose validation failed for: $compose_file"
            ((compose_errors++))
        fi
    done < <(find . -name "docker-compose*.yml" -print0)

    if [[ $compose_errors -eq 0 ]]; then
        log_success "All Docker Compose files are valid"
    else
        log_error "Found $compose_errors Docker Compose validation errors"
        integration_test_success=false
    fi

    local integration_test_end=$(date +%s)
    local integration_test_duration=$((integration_test_end - integration_test_start))

    if [[ "$integration_test_success" == "true" ]]; then
        INTEGRATION_TEST_RESULTS="✓ PASSED (${integration_test_duration}s)"
        log_success "Integration tests completed successfully in ${integration_test_duration}s"
    else
        INTEGRATION_TEST_RESULTS="✗ FAILED (${integration_test_duration}s)"
        log_error "Integration tests failed in ${integration_test_duration}s"
        OVERALL_SUCCESS=false
    fi
}

# Run CI/CD tests
run_cicd_tests() {
    log_section "Running CI/CD Tests"

    local cicd_test_start=$(date +%s)
    local cicd_test_success=true

    # Test GitHub Actions workflow syntax
    if [[ -f "$PROJECT_ROOT/.github/workflows/test.yml" ]]; then
        log_info "Validating GitHub Actions workflow..."
        if python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.github/workflows/test.yml'))" 2>/dev/null; then
            log_success "GitHub Actions workflow syntax is valid"
        else
            log_error "GitHub Actions workflow has syntax errors"
            cicd_test_success=false
        fi
    fi

    # Test example configuration for CI/CD
    log_info "Testing example configuration for CI/CD..."
    if [[ -f "$SCRIPT_DIR/example-site.yml" ]]; then
        if python3 -c "
import yaml
import sys
try:
    with open('$SCRIPT_DIR/example-site.yml', 'r') as f:
        config = yaml.safe_load(f)

    # Validate structure for CI/CD
    site = config['site']
    required = ['name', 'display_name', 'network_prefix', 'domain', 'proxmox', 'vm_templates']
    for field in required:
        assert field in site, f'Missing required field: {field}'

    print('✓ Example configuration is valid for CI/CD')
except Exception as e:
    print(f'✗ Example configuration validation failed: {e}')
    sys.exit(1)
"; then
            log_success "Example configuration is valid for CI/CD"
        else
            log_error "Example configuration validation failed"
            cicd_test_success=false
        fi
    fi

    # Test site creation script
    log_info "Testing site creation script..."
    if [[ -f "$PROJECT_ROOT/deployment/scripts/create_site_config.sh" ]]; then
        if bash -n "$PROJECT_ROOT/deployment/scripts/create_site_config.sh" 2>/dev/null; then
            log_success "Site creation script syntax is valid"
        else
            log_error "Site creation script has syntax errors"
            cicd_test_success=false
        fi
    fi

    # Test documentation consistency
    log_info "Testing documentation consistency..."
    local doc_errors=0

    # Check that README mentions the simplified approach
    if ! grep -q "single YAML file" "$PROJECT_ROOT/README.md" 2>/dev/null; then
        log_error "Main README doesn't mention simplified YAML approach"
        ((doc_errors++))
    fi

    # Check that config README is updated
    if ! grep -q "One YAML file per site" "$PROJECT_ROOT/config/README.md" 2>/dev/null; then
        log_error "Config README doesn't mention single YAML approach"
        ((doc_errors++))
    fi

    if [[ $doc_errors -eq 0 ]]; then
        log_success "Documentation is consistent"
    else
        log_error "Found $doc_errors documentation consistency issues"
        cicd_test_success=false
    fi

    local cicd_test_end=$(date +%s)
    local cicd_test_duration=$((cicd_test_end - cicd_test_start))

    if [[ "$cicd_test_success" == "true" ]]; then
        CICD_TEST_RESULTS="✓ PASSED (${cicd_test_duration}s)"
        log_success "CI/CD tests completed successfully in ${cicd_test_duration}s"
    else
        CICD_TEST_RESULTS="✗ FAILED (${cicd_test_duration}s)"
        log_error "CI/CD tests failed in ${cicd_test_duration}s"
        OVERALL_SUCCESS=false
    fi
}

# Cleanup
cleanup() {
    if [[ "$CLEANUP_AFTER" == "true" ]]; then
        log_section "Cleaning Up"
        cd "$SCRIPT_DIR"

        log_info "Stopping Docker containers..."
        docker-compose down >/dev/null 2>&1 || true

        log_success "Cleanup completed"
    fi
}

# Generate test report
generate_report() {
    log_section "Test Results Summary"

    local report_file="$SCRIPT_DIR/reports/test-report-$(date +%Y%m%d-%H%M%S).json"
    mkdir -p "$(dirname "$report_file")"

    # Create JSON report
    cat > "$report_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "overall_success": $OVERALL_SUCCESS,
  "test_results": {
    "unit_tests": {
      "enabled": $RUN_UNIT_TESTS,
      "result": "$UNIT_TEST_RESULTS"
    },
    "integration_tests": {
      "enabled": $RUN_INTEGRATION_TESTS,
      "result": "$INTEGRATION_TEST_RESULTS"
    },
    "cicd_tests": {
      "enabled": $RUN_CICD_TESTS,
      "result": "$CICD_TEST_RESULTS"
    }
  },
  "configuration": {
    "verbose": $VERBOSE,
    "parallel": $PARALLEL_TESTS,
    "cleanup": $CLEANUP_AFTER
  }
}
EOF

    # Display summary
    echo -e "\n${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TEST RESULTS SUMMARY       ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"

    if [[ "$RUN_UNIT_TESTS" == "true" ]]; then
        echo -e "${BLUE}║${NC} Unit Tests:        $UNIT_TEST_RESULTS"
    fi

    if [[ "$RUN_INTEGRATION_TESTS" == "true" ]]; then
        echo -e "${BLUE}║${NC} Integration Tests: $INTEGRATION_TEST_RESULTS"
    fi

    if [[ "$RUN_CICD_TESTS" == "true" ]]; then
        echo -e "${BLUE}║${NC} CI/CD Tests:       $CICD_TEST_RESULTS"
    fi

    echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"

    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        echo -e "${BLUE}║${NC} ${GREEN}Overall Result: ✓ ALL TESTS PASSED${NC}   ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║${NC} ${RED}Overall Result: ✗ SOME TESTS FAILED${NC}  ${BLUE}║${NC}"
    fi

    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"

    log_info "Detailed report saved to: $report_file"
}

# Main execution
main() {
    local start_time=$(date +%s)

    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Proxmox Firewall Test Suite                    ║"
    echo "║                 Comprehensive Testing                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Setup
    check_prerequisites
    setup_test_environment

    # Run tests based on configuration
    if [[ "$RUN_UNIT_TESTS" == "true" ]]; then
        run_unit_tests
    fi

    if [[ "$RUN_INTEGRATION_TESTS" == "true" ]]; then
        run_integration_tests
    fi

    if [[ "$RUN_CICD_TESTS" == "true" ]]; then
        run_cicd_tests
    fi

    # Cleanup and report
    cleanup
    generate_report

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    log_info "Total test execution time: ${total_duration}s"

    # Exit with appropriate code
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
