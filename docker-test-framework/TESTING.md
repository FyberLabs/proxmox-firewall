# Testing Framework Documentation

This document describes the comprehensive testing strategy for the Proxmox Firewall deployment system.

## Testing Philosophy

Our testing approach validates the **simplified single-YAML configuration** system through multiple layers:

1. **Unit Tests** - Fast validation of individual components
2. **Integration Tests** - Full system testing with mock infrastructure  
3. **CI/CD Tests** - Automated validation for continuous integration
4. **Configuration Validation** - User-friendly local validation

## Test Structure

```
tests/                          # Unit tests (no Docker required)
├── test_config_validation.py   # Configuration validation tests
└── README.md                   # Unit test documentation

docker-test-framework/          # Integration tests (with Docker)
├── test_integration.py         # Comprehensive integration tests
├── test_simplified_config.py   # Single-YAML approach validation
├── run-comprehensive-tests.sh  # Master test orchestrator
├── run-integration-tests.sh    # Integration test runner
├── example-site.yml            # Static example for CI/CD
└── TESTING.md                  # This file

validate-config.sh              # Quick local validation script
.github/workflows/test.yml      # CI/CD automation
```

## Running Tests

### Quick Local Validation

For fast local validation of your configuration:

```bash
# Validate all configurations
./validate-config.sh

# Validate specific site
./validate-config.sh mysite

# Get help
./validate-config.sh --help
```

### Unit Tests (Fast)

Run unit tests without Docker:

```bash
cd tests
python -m pytest test_config_validation.py -v
```

### Integration Tests (Comprehensive)

Run full integration tests with mock infrastructure:

```bash
cd docker-test-framework

# Run all tests
./run-comprehensive-tests.sh

# Run only unit tests (fast)
./run-comprehensive-tests.sh --unit-only

# Run only integration tests
./run-comprehensive-tests.sh --integration-only

# Run with verbose output
./run-comprehensive-tests.sh --verbose
```

### CI/CD Tests

Automated tests run on every push/PR via GitHub Actions:

```bash
# Locally simulate CI/CD
cd docker-test-framework
./run-comprehensive-tests.sh --cicd-only
```

## Test Categories

### 1. Configuration Validation Tests

**Purpose**: Validate YAML syntax and structure
**Location**: `tests/test_config_validation.py`, `validate-config.sh`
**Speed**: Very fast (< 5 seconds)

Tests:
- ✅ YAML syntax validation
- ✅ Required field validation  
- ✅ Network configuration consistency
- ✅ Credential reference validation
- ✅ Site template validation

### 2. Simplified Configuration Tests

**Purpose**: Validate single-YAML approach works correctly
**Location**: `docker-test-framework/test_simplified_config.py`
**Speed**: Fast (< 30 seconds)

Tests:
- ✅ No duplicate configuration files
- ✅ Ansible can read single YAML
- ✅ Environment variable generation
- ✅ Site creation script validation
- ✅ Migration path validation

### 3. Integration Tests

**Purpose**: Test complete deployment pipeline with mock infrastructure
**Location**: `docker-test-framework/test_integration.py`
**Speed**: Medium (2-5 minutes)

Tests:
- ✅ Mock Proxmox API integration
- ✅ Mock OPNsense API integration
- ✅ Ansible playbook execution
- ✅ Terraform variable passing
- ✅ End-to-end deployment simulation

### 4. CI/CD Tests

**Purpose**: Ensure configurations work in automated environments
**Location**: `.github/workflows/test.yml`
**Speed**: Medium (3-10 minutes)

Tests:
- ✅ Static example configuration validation
- ✅ GitHub Actions workflow validation
- ✅ Docker Compose validation
- ✅ Documentation consistency
- ✅ Deployment script validation

## Test Configuration Files

### Static Example Configuration

**File**: `docker-test-framework/example-site.yml`
**Purpose**: Static configuration for CI/CD testing

This file:
- Contains a complete, valid site configuration
- Uses safe test values (10.99.x.x network)
- Is automatically validated in CI/CD
- Serves as a reference implementation

### Site Template

**File**: `config/site_template.yml`
**Purpose**: Template for users to create new sites

This file:
- Contains all possible configuration options
- Includes helpful comments and examples
- Is validated to ensure it's always correct
- Can be copied and customized by users

## Mock Infrastructure

The testing framework includes mock services that simulate real infrastructure:

### Proxmox Mock (`proxmox-mock/`)
- Simulates Proxmox VE API
- Handles VM creation/management requests
- Returns realistic responses
- Validates API call structure

### OPNsense Mock (`opnsense-mock/`)
- Simulates OPNsense firewall API
- Handles configuration requests
- Validates firewall rule structure
- Tests network configuration

### Network Simulator (`network-sim/`)
- Simulates network topology
- Tests VLAN configuration
- Validates bridge setup
- Checks network connectivity

## CI/CD Integration

### GitHub Actions Workflow

The CI/CD pipeline runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`

**Stages**:
1. **Unit Tests** - Fast validation (< 2 minutes)
2. **Comprehensive Tests** - Full integration testing (< 10 minutes)
3. **Configuration Validation** - Validate all configs (< 1 minute)

**Artifacts**:
- Test results (JSON reports)
- Test logs (for debugging failures)
- Coverage reports (if applicable)

### Test Results

Test results are saved in multiple formats:
- **JSON Reports**: `docker-test-framework/reports/`
- **Test Logs**: `docker-test-framework/logs/`
- **JUnit XML**: For CI/CD integration

## Writing New Tests

### Adding Unit Tests

1. Add test functions to `tests/test_config_validation.py`
2. Use standard Python `unittest` framework
3. Focus on fast, isolated validation
4. No external dependencies (Docker, network)

```python
def test_new_validation(self):
    """Test description"""
    # Test implementation
    self.assertTrue(condition, "Error message")
```

### Adding Integration Tests

1. Add test methods to `docker-test-framework/test_integration.py`
2. Use mock services for external dependencies
3. Test complete workflows
4. Include cleanup in tearDown

```python
def test_new_integration(self):
    """Test description"""
    # Setup
    # Test implementation
    # Assertions
    # Cleanup handled automatically
```

### Adding Configuration Tests

1. Add validation to `validate-config.sh`
2. Use Python for complex validation logic
3. Provide clear error messages
4. Support both single-site and all-site validation

## Troubleshooting Tests

### Common Issues

**Mock services not starting**:
```bash
cd docker-test-framework
docker-compose down
docker-compose up -d
docker-compose logs
```

**Python dependencies missing**:
```bash
pip3 install pyyaml requests pytest
```

**Ansible not available**:
```bash
pip3 install ansible
```

**Docker not running**:
```bash
sudo systemctl start docker
```

### Debug Mode

Run tests with verbose output:
```bash
./run-comprehensive-tests.sh --verbose
```

Check test logs:
```bash
cat docker-test-framework/logs/integration_tests.log
```

View test results:
```bash
cat docker-test-framework/reports/test-report-*.json
```

## Best Practices

### Configuration Testing
- ✅ Always validate YAML syntax first
- ✅ Test network configuration consistency
- ✅ Validate credential references
- ✅ Check for duplicate configurations
- ✅ Test both positive and negative cases

### Integration Testing
- ✅ Use mock services for external dependencies
- ✅ Test complete workflows end-to-end
- ✅ Include error handling scenarios
- ✅ Clean up resources after tests
- ✅ Make tests deterministic and repeatable

### CI/CD Testing
- ✅ Use static example configurations
- ✅ Test in clean environments
- ✅ Validate all documentation
- ✅ Check for breaking changes
- ✅ Provide clear failure messages

## Performance Targets

- **Unit Tests**: < 30 seconds total
- **Integration Tests**: < 5 minutes total
- **CI/CD Pipeline**: < 15 minutes total
- **Local Validation**: < 10 seconds

## Maintenance

### Regular Tasks
- Update example configurations when adding features
- Validate test coverage for new functionality
- Update mock services to match real API changes
- Review and update documentation

### Monitoring
- CI/CD success rates
- Test execution times
- Coverage metrics
- User feedback on validation tools

This testing framework ensures that our simplified single-YAML configuration approach works reliably across all environments and use cases. 