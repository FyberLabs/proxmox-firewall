#!/bin/bash
set -euo pipefail

# Docker Testing Framework - Main Test Runner
# Usage: ./scripts/run-tests.sh [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
TEST_SUITE="all"
TEST_PARALLEL="true"
TEST_DEBUG="false"
TEST_CLEAN="false"
TEST_LOAD=""
TEST_DURATION="300"
COMPOSE_FILE="$PROJECT_DIR/compose/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/configs/test.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Help function
show_help() {
    cat << EOF
Docker Testing Framework - Test Runner

Usage: $0 [OPTIONS]

OPTIONS:
    -s, --suite SUITE        Test suite to run (default: all)
                            Options: all, network, firewall, vm-deployment,
                                   integration, performance
    -p, --parallel BOOL      Run tests in parallel (default: true)
    -d, --debug BOOL         Enable debug mode (default: false)
    -c, --clean             Clean up before running tests
    -l, --load LEVEL        Load testing level (low, medium, high)
    -t, --duration SECONDS  Test duration for performance tests (default: 300)
    -e, --env-file FILE     Environment file (default: configs/test.env)
    -f, --compose-file FILE Docker compose file (default: compose/docker-compose.yml)
    -h, --help              Show this help message

EXAMPLES:
    $0                                    # Run all tests
    $0 --suite network                   # Run only network tests
    $0 --suite performance --load high   # Run performance tests with high load
    $0 --debug true --clean              # Run with debug and cleanup
    $0 --suite integration --parallel false  # Run integration tests sequentially

TEST SUITES:
    all            - Run all test suites
    network        - Network configuration and VLAN tests
    firewall       - Firewall rules and security tests
    vm-deployment  - VM creation, configuration, and management tests
    integration    - End-to-end integration tests
    performance    - Performance and load testing

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--suite)
                TEST_SUITE="$2"
                shift 2
                ;;
            -p|--parallel)
                TEST_PARALLEL="$2"
                shift 2
                ;;
            -d|--debug)
                TEST_DEBUG="$2"
                shift 2
                ;;
            -c|--clean)
                TEST_CLEAN="true"
                shift
                ;;
            -l|--load)
                TEST_LOAD="$2"
                shift 2
                ;;
            -t|--duration)
                TEST_DURATION="$2"
                shift 2
                ;;
            -e|--env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            -f|--compose-file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."

    # Check if docker and docker-compose are available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    # Check if compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    # Check if env file exists, create from example if not
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f "$ENV_FILE.example" ]]; then
            log_warning "Environment file not found, copying from example"
            cp "$ENV_FILE.example" "$ENV_FILE"
        else
            log_error "Environment file not found: $ENV_FILE"
            exit 1
        fi
    fi

    log_success "Environment validation passed"
}

# Setup test environment
setup_environment() {
    log_info "Setting up test environment..."

    # Set environment variables
    export TEST_SUITE="$TEST_SUITE"
    export TEST_PARALLEL="$TEST_PARALLEL"
    export TEST_DEBUG="$TEST_DEBUG"
    export TEST_LOAD="$TEST_LOAD"
    export TEST_DURATION="$TEST_DURATION"

    # Create necessary directories
    mkdir -p "$PROJECT_DIR/reports"
    mkdir -p "$PROJECT_DIR/logs"

    # Generate SSH keys if they don't exist
    if [[ ! -f "$PROJECT_DIR/test-keys/id_rsa" ]]; then
        log_info "Generating test SSH keys..."
        mkdir -p "$PROJECT_DIR/test-keys"
        ssh-keygen -t rsa -b 2048 -f "$PROJECT_DIR/test-keys/id_rsa" -N "" -C "test@docker-framework"
    fi

    log_success "Test environment setup completed"
}

# Cleanup function
cleanup() {
    if [[ "$TEST_CLEAN" == "true" ]]; then
        log_info "Cleaning up previous test environment..."

        cd "$PROJECT_DIR"
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v --remove-orphans || true

        # Remove test volumes
        docker volume ls -q | grep -E "^docker-test-framework_" | xargs -r docker volume rm || true

        # Remove test networks
        docker network ls -q | grep -E "docker-test-framework" | xargs -r docker network rm || true

        log_success "Cleanup completed"
    fi
}

# Start services
start_services() {
    log_info "Starting test services..."

    cd "$PROJECT_DIR"

    # Pull latest images
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull --quiet

    # Start infrastructure services first
    log_info "Starting infrastructure services..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d \
        redis postgres prometheus grafana elasticsearch logstash kibana

    # Wait for infrastructure to be ready
    sleep 10

    # Start mock services
    log_info "Starting mock services..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d \
        proxmox-mock opnsense-mock network-sim

    # Wait for services to be ready
    log_info "Waiting for services to be ready..."

    # Check Proxmox mock health
    timeout=60
    while [[ $timeout -gt 0 ]]; do
        if curl -sf http://localhost:8006/health &>/dev/null; then
            break
        fi
        sleep 2
        ((timeout -= 2))
    done

    if [[ $timeout -le 0 ]]; then
        log_error "Proxmox mock service failed to start"
        exit 1
    fi

    # Check OPNsense mock health
    timeout=60
    while [[ $timeout -gt 0 ]]; do
        if curl -skf https://localhost:8443/health &>/dev/null; then
            break
        fi
        sleep 2
        ((timeout -= 2))
    done

    if [[ $timeout -le 0 ]]; then
        log_error "OPNsense mock service failed to start"
        exit 1
    fi

    log_success "All services started successfully"
}

# Run tests
run_tests() {
    log_info "Running test suite: $TEST_SUITE"

    cd "$PROJECT_DIR"

    # Run the test runner container
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" run --rm test-runner

    # Capture exit code
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Tests completed successfully"
    else
        log_error "Tests failed with exit code: $exit_code"
    fi

    return $exit_code
}

# Generate test report
generate_report() {
    log_info "Generating test report..."

    local report_dir="$PROJECT_DIR/reports"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="$report_dir/test_report_${timestamp}.html"

    # Check if reports exist
    if [[ -d "$report_dir" ]] && [[ -n "$(ls -A "$report_dir" 2>/dev/null)" ]]; then
        log_info "Test report generated: $report_file"
        log_info "View reports at: http://localhost:3000 (Grafana)"
        log_info "View logs at: http://localhost:5601 (Kibana)"
        log_info "View metrics at: http://localhost:9090 (Prometheus)"
    else
        log_warning "No test reports found"
    fi
}

# Shutdown services
shutdown_services() {
    log_info "Shutting down services..."

    cd "$PROJECT_DIR"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down

    log_success "Services shut down"
}

# Main function
main() {
    parse_args "$@"

    log_info "Starting Docker Testing Framework"
    log_info "Test suite: $TEST_SUITE"
    log_info "Parallel execution: $TEST_PARALLEL"
    log_info "Debug mode: $TEST_DEBUG"

    # Setup trap for cleanup
    trap 'log_error "Test interrupted"; shutdown_services; exit 1' INT TERM

    validate_environment
    setup_environment
    cleanup
    start_services

    # Run tests and capture exit code
    local test_exit_code=0
    run_tests || test_exit_code=$?

    generate_report

    # Don't shutdown services if debug mode is enabled
    if [[ "$TEST_DEBUG" != "true" ]]; then
        shutdown_services
    else
        log_info "Debug mode enabled - services left running"
        log_info "Access services at:"
        log_info "  Proxmox Mock: http://localhost:8006"
        log_info "  OPNsense Mock: https://localhost:8443"
        log_info "  Grafana: http://localhost:3000"
        log_info "  Kibana: http://localhost:5601"
        log_info "Run 'docker-compose down' to stop services"
    fi

    if [[ $test_exit_code -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_error "Some tests failed"
    fi

    exit $test_exit_code
}

# Run main function with all arguments
main "$@"
