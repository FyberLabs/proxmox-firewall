# GitHub Templates and Workflows

This directory contains GitHub-specific templates and automation workflows for the Proxmox Firewall project.

## 📋 Issue Templates

We provide structured issue templates to help users report issues effectively and maintainers triage them efficiently.

### Available Templates:

- **🐛 Bug Report** (`bug_report.yml`) - Report bugs or unexpected behavior
- **🚀 Feature Request** (`feature_request.yml`) - Suggest new features or enhancements  
- **📚 Documentation Issue** (`documentation.yml`) - Report documentation problems or improvements
- **❓ Question/Support** (`question.yml`) - Ask questions or get help with setup/configuration
- **📝 Blank Issue** (`blank.yml`) - For cases not covered by other templates

### Template Configuration:

- **`config.yml`** - Configures issue template behavior and provides helpful links
- Disables blank issues to encourage use of structured templates
- Provides quick links to security reporting, discussions, documentation, and FAQ

## 🔄 Pull Request Template

- **`pull_request_template.md`** - Comprehensive template for pull requests
- Includes sections for description, testing, checklist, and compliance
- Helps ensure consistent and complete pull request information

## 🤖 Workflows

The `workflows/` directory contains GitHub Actions for:
- Continuous Integration (CI)
- Automated testing
- Documentation generation
- Security scanning
- Release automation

## 📝 Template Features

### Structured Data Collection:
- **Dropdowns** for categorization and priority
- **Checkboxes** for prerequisites and checklists
- **Text areas** with helpful placeholders and examples
- **Required fields** to ensure essential information is provided

### Project-Specific Categories:
- Proxmox Setup/Configuration
- Network Configuration (VLANs, Bridges)
- VM Deployment (Terraform)
- OPNsense Firewall Configuration
- Tailscale VPN Integration
- Security Monitoring (Suricata/Zeek)
- Device Management
- Scripts/Automation

### Helpful Guidance:
- Clear instructions and examples
- Links to relevant documentation
- Prerequisites to check before submitting
- Contribution opportunities for community involvement

## 🔗 Quick Links

When creating issues, users are provided with quick access to:
- 🔒 [Security Vulnerability Reporting](https://github.com/FyberLabs/proxmox-firewall/security/advisories/new)
- 💬 [GitHub Discussions](https://github.com/FyberLabs/proxmox-firewall/discussions)
- 📖 [Documentation](https://github.com/FyberLabs/proxmox-firewall/tree/main/docs)
- 🔧 [Troubleshooting Guide](https://github.com/FyberLabs/proxmox-firewall/blob/main/docs/TROUBLESHOOTING.md)
- ❓ [FAQ](https://github.com/FyberLabs/proxmox-firewall/blob/main/docs/reference/FAQ.md)

## 📧 Contact Information

For general repository inquiries, collaboration opportunities, or questions that don't fit the issue templates:
- **Email**: github@fyberlabs.com
- **Security Issues**: security@fyberlabs.com (or use GitHub Security Advisories)

## 🎯 Benefits

These templates help:
- **Users**: Provide clear guidance on what information to include
- **Maintainers**: Receive consistent, well-structured issues that are easier to triage
- **Community**: Reduce back-and-forth questions and faster issue resolution
- **Project**: Maintain high-quality issue tracking and documentation 
