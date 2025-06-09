# Docker Test Framework - Integration Testing

This framework provides comprehensive integration testing for the Proxmox firewall deployment system using Docker containers to simulate the complete infrastructure.

## Testing Strategy

### 1. Static Example Configs (CI/CD)
- **`example-site.yml`** - Static site configuration for automated testing
- **`config/devices/test-site/`** - Static device configurations  
- **Purpose**: CI/CD pipelines, regression testing, consistent baseline

### 2. User Config Testing
- Test real user configurations from `config/sites/` and `config/devices/`
- Validate deployment workflows with actual site configs
- Verify configuration compatibility and deployment success

### 3. Full Integration Testing
- End-to-end deployment simulation using real Ansible and Terraform
- Mock Proxmox, OPNsense, and network infrastructure
- Network connectivity and firewall rule validation

## Overview

The framework simulates:
- Proxmox VE environment with API endpoints
- OPNsense firewall configuration
- Network topology and VLAN configurations
- VM deployment and management
- Ansible playbook execution
- Terraform state management

## Architecture

```
docker-test-framework/
├── compose/                    # Docker Compose configurations
│   ├── docker-compose.yml    # Main testing environment
│   ├── docker-compose.dev.yml # Development overrides
│   └── docker-compose.ci.yml  # CI/CD specific configuration
├── proxmox-mock/              # Proxmox VE API mock service
├── opnsense-mock/             # OPNsense API mock service
├── network-sim/               # Network topology simulator
├── test-runner/               # Test execution environment
├── configs/                   # Test configuration files
├── scripts/                   # Helper scripts
└── tests/                     # Test suites
```

## Components

### 1. Proxmox Mock Service
- Simulates Proxmox VE API endpoints
- Handles VM creation, configuration, and management
- Provides storage and network management APIs
- Supports cluster and node operations

### 2. OPNsense Mock Service
- Simulates OPNsense firewall API
- Handles VLAN, firewall rule, and interface configuration
- Provides VPN and routing configuration endpoints
- Supports backup and restore operations

### 3. Network Simulator
- Creates virtual network topologies
- Simulates VLANs and network interfaces
- Provides connectivity testing between components
- Monitors network traffic and routing

### 4. Test Runner
- Executes Ansible playbooks in isolated environment
- Runs Terraform operations against mock services
- Provides test orchestration and reporting
- Supports parallel test execution

## Quick Start

1. **Setup Environment**:
   ```bash
   cd docker-test-framework
   cp configs/test.env.example configs/test.env
   # Edit test.env with your test configuration
   ```

2. **Start Testing Environment**:
   ```bash
   docker-compose up -d
   ```

3. **Run Full Deployment Test**:
   ```bash
   ./scripts/test-full-deployment.sh
   ```

4. **Run Specific Test Suite**:
   ```bash
   ./scripts/run-tests.sh --suite=network
   ./scripts/run-tests.sh --suite=firewall
   ./scripts/run-tests.sh --suite=vm-deployment
   ```

## Test Suites

### Network Configuration Tests
- VLAN creation and configuration
- Interface assignment and routing
- Network isolation and security
- Failover and redundancy testing

### Firewall Configuration Tests
- Rule creation and validation
- Port forwarding and NAT
- VPN configuration
- IDS/IPS functionality

### VM Deployment Tests
- Template creation and management
- VM provisioning and configuration
- Resource allocation and monitoring
- Backup and restore operations

### Integration Tests
- End-to-end deployment scenarios
- Multi-site configuration
- Failover and disaster recovery
- Performance and load testing

## Configuration

### Test Environment Variables

```bash
# Proxmox Mock Configuration
PROXMOX_MOCK_HOST=proxmox-mock
PROXMOX_MOCK_PORT=8006
PROXMOX_MOCK_API_VERSION=v2

# OPNsense Mock Configuration
OPNSENSE_MOCK_HOST=opnsense-mock
OPNSENSE_MOCK_PORT=443
OPNSENSE_MOCK_API_VERSION=v1

# Network Simulation
NETWORK_BRIDGE_PREFIX=test-br
VLAN_RANGE_START=10
VLAN_RANGE_END=50

# Test Data
TEST_SITE_PREFIX=10.100
TEST_DOMAIN=test.local
TEST_SSH_KEY_PATH=/test-keys/id_rsa
```

### Mock Service Configuration

The mock services can be configured to simulate various scenarios:
- Network failures and timeouts
- API rate limiting and errors
- Resource constraints
- Hardware failure scenarios

## Advanced Usage

### Custom Test Scenarios

Create custom test scenarios by adding configuration files to `configs/scenarios/`:

```yaml
# configs/scenarios/multi-site-failover.yml
name: "Multi-Site Failover Test"
description: "Tests failover between Secondary and Primary Home sites"
sites:
  - name: "tn"
    network_prefix: "10.1"
    simulate_failure: true
    failure_type: "wan_outage"
  - name: "ph" 
    network_prefix: "10.2"
    simulate_failure: false
duration: 300
expected_outcomes:
  - "Traffic routes through backup site"
  - "VPN connections maintain connectivity"
  - "Critical services remain available"
```

### Performance Testing

Enable performance monitoring and load testing:

```bash
./scripts/run-tests.sh --suite=performance --load=high --duration=3600
```

### CI/CD Integration

For continuous integration, use the CI-specific compose file:

```bash
docker-compose -f docker-compose.yml -f docker-compose.ci.yml up --abort-on-container-exit
```

## Monitoring and Debugging

### Log Access
```bash
# View all service logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f proxmox-mock
docker-compose logs -f test-runner
```

### Debug Mode
```bash
# Start with debug logging enabled
TEST_DEBUG=true docker-compose up -d
```

### Test Reports

Test results are automatically generated in `reports/` directory:
- HTML test reports
- JSON test data
- Performance metrics
- Coverage reports

## Cleanup

```bash
# Stop and remove all containers
docker-compose down -v

# Remove test data and reports
./scripts/cleanup.sh --all
```

## Contributing

1. Add new test cases to appropriate test suites
2. Update mock services to support new API endpoints
3. Document any new configuration options
4. Ensure tests are idempotent and can run in parallel

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 8006, 443, and others are not in use
2. **Network Issues**: Check Docker network configuration and bridge settings
3. **Resource Limits**: Increase Docker memory/CPU limits if tests timeout
4. **Mock Service Errors**: Check mock service logs for API endpoint issues

### Getting Help

1. Check the logs: `docker-compose logs`
2. Review test output in `reports/` directory
3. Run individual components for debugging
4. Check mock service health endpoints 
