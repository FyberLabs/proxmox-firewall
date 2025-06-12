# Documentation Index

Welcome to the Proxmox Firewall project documentation! This directory contains comprehensive guides and references for all aspects of the project.

## 📚 Documentation Overview

### 🚀 Getting Started
- **[Main README](../README.md)** - Project overview and quick start
- **[Contributing Guide](../CONTRIBUTING.md)** - How to contribute to the project
- **[Security Policy](../SECURITY.md)** - Security practices and vulnerability reporting

### 🔧 Setup and Installation
- **[Prerequisites Guide](setup/PREREQUISITES.md)** - System requirements and dependencies
- **[Hardware Setup](setup/HARDWARE.md)** - Hardware configuration and recommendations
- **[Network Planning](setup/NETWORK_PLANNING.md)** - Network design and VLAN configuration

### 🚀 Deployment
- **[Deployment Guide](../deployment/README.md)** - Automated deployment with Ansible
- **[Site Configuration](../proxmox-local/ansible/SITE_CONFIG.md)** - Site-specific configuration management
- **[Manual Installation](deployment/MANUAL_INSTALLATION.md)** - Step-by-step manual setup

### ⚙️ Configuration
- **[Network Configuration](../config/NETWORK_PREFIX_FORMAT.md)** - VLAN and network design
- **[Multi-site Setup](../README_MULTISITE.md)** - Managing multiple locations
- **[Device Management](../README_DEVICES.md)** - Network device configuration
- **[OPNsense Configuration](configuration/OPNSENSE.md)** - Firewall setup and rules
- **[VPN Configuration](configuration/VPN.md)** - Tailscale and VPN setup

### 🔐 Security
- **[Security Overview](SECURITY.md)** - Security features and best practices
- **[Firewall Rules](configuration/FIREWALL_RULES.md)** - Detailed firewall configuration
- **[Monitoring Setup](configuration/MONITORING.md)** - IDS/IPS and network monitoring

### 🧪 Testing
- **[Testing Guide](../tests/README.md)** - Automated testing and validation
- **[Docker Test Environment](../docker-test-framework/QUICK_START.md)** - Local development and testing
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

### 🔌 Integration
- **[API Documentation](API.md)** - API reference for automation
- **[Automation Examples](integration/AUTOMATION.md)** - Scripts and automation examples
- **[Monitoring Integration](integration/MONITORING.md)** - Prometheus, Grafana, and alerting

### 📋 Reference
- **[Changelog](../CHANGELOG.md)** - Release notes and changes
- **[TODO](../TODO.md)** - Planned features and improvements
- **[FAQ](reference/FAQ.md)** - Frequently asked questions
- **[Glossary](reference/GLOSSARY.md)** - Technical terms and definitions

## 🏗️ Documentation Structure

```
docs/
├── README.md                 # This index file
├── API.md                   # API documentation
├── SECURITY.md              # Security policy
├── TROUBLESHOOTING.md       # Common issues and solutions
├── setup/                   # Installation and setup guides
├── deployment/              # Deployment documentation
├── configuration/           # Configuration guides
├── integration/             # API and automation guides
└── reference/               # Reference materials
```

## 📖 Documentation Guidelines

### Writing Documentation

When contributing documentation:

1. **Use clear headings** with emoji for visual organization
2. **Include code examples** with proper syntax highlighting
3. **Add troubleshooting sections** for common issues
4. **Keep examples up-to-date** with current configuration formats
5. **Cross-reference related documents** with relative links

### Documentation Standards

- **Markdown format** for all documentation files
- **Consistent emoji usage** for section headers
- **Code blocks** with language specification
- **Relative links** for internal references
- **Examples** should be complete and runnable

## 🆘 Need Help?

If you can't find what you're looking for:

1. **Search the documentation** using your browser's find function
2. **Check the troubleshooting guide** for common issues
3. **Review the FAQ** for frequently asked questions
4. **Create a GitHub issue** if you found a documentation gap
5. **Join GitHub Discussions** for community help

## 🤝 Contributing to Documentation

Documentation improvements are always welcome! See our [Contributing Guide](../CONTRIBUTING.md) for:

- How to submit documentation updates
- Writing style guidelines
- Review process for documentation changes
- Tips for creating clear, helpful guides

---

**Last Updated**: 2025-01-12  
**Version**: 1.0.0 
