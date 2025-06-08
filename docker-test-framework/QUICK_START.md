# Quick Start Guide - Docker Testing Framework

This guide will help you get the Docker Testing Framework up and running quickly to test your Proxmox firewall deployment.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available for containers
- Ports 8006, 8443, 3000, 5601, 9090 available

## 1. Initial Setup

```bash
# Navigate to the testing framework
cd docker-test-framework

# Copy the environment configuration
cp configs/test.env.example configs/test.env

# Edit the configuration if needed (optional for basic testing)
# nano configs/test.env
```

## 2. Quick Test Run

### Option A: Run all tests (recommended for first time)
```bash
./scripts/run-tests.sh
```

### Option B: Run specific test suite
```bash
# Network configuration tests
./scripts/run-tests.sh --suite network

# VM deployment tests  
./scripts/run-tests.sh --suite vm-deployment

# Firewall configuration tests
./scripts/run-tests.sh --suite firewall

# Full integration tests
./scripts/run-tests.sh --suite integration
```

### Option C: Quick full deployment test
```bash
./scripts/test-full-deployment.sh
```

## 3. Monitor Test Progress

While tests are running, you can monitor progress through the web interfaces:

- **Proxmox Mock API**: http://localhost:8006
- **OPNsense Mock API**: https://localhost:8443 (self-signed cert)
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)
- **Kibana Logs**: http://localhost:5601
- **Prometheus Metrics**: http://localhost:9090

## 4. Debug Mode

To keep services running after tests for debugging:

```bash
./scripts/run-tests.sh --debug true
```

This will leave all services running so you can:
- Inspect mock service responses
- Review logs in Kibana
- Check metrics in Grafana
- Debug test failures

Stop services when done:
```bash
cd compose && docker-compose down
```

## 5. Clean Environment

To start with a fresh environment:

```bash
./scripts/run-tests.sh --clean
```

## Test Results

Test results are saved in:
- `reports/` - HTML test reports and coverage
- `logs/` - Detailed test execution logs
- Web dashboards for real-time monitoring

## Common Issues

### Port Conflicts
If you get port binding errors:
```bash
# Check what's using the ports
sudo netstat -tulpn | grep :8006
sudo netstat -tulpn | grep :8443

# Stop conflicting services or change ports in configs/test.env
```

### Memory Issues
If containers fail to start:
```bash
# Check available memory
free -h

# Reduce services by commenting out in compose/docker-compose.yml:
# - elasticsearch
# - kibana
# - grafana (keep prometheus for basic monitoring)
```

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh

# Check Docker permissions
sudo usermod -aG docker $USER
# Then logout and login again
```

## Next Steps

1. **Customize Tests**: Add your own test scenarios in `tests/`
2. **Configure Mock Services**: Modify mock behavior in `configs/`
3. **Performance Testing**: Use `--load high` for stress testing
4. **CI/CD Integration**: Use `compose/docker-compose.ci.yml`

## Help

For more options and advanced usage:
```bash
./scripts/run-tests.sh --help
```

For detailed documentation, see the main [README.md](README.md). 
