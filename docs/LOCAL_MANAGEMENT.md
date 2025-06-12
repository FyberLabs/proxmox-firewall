# 🏠 Local Management System

This document describes how to set up and use the Local Management System for Proxmox Firewall. This system allows your Proxmox server to automatically manage its own configuration by syncing with your GitHub fork and applying updates.

## 🎯 Overview

The Local Management System provides:

- **🔄 Automatic Updates**: Proxmox server pulls configuration changes from your GitHub fork
- **🏗️ Local Terraform State**: Terraform state stored securely on the Proxmox server
- **📋 Continuous Monitoring**: Regular checks for configuration drift and updates
- **🔒 Secure Operation**: All sensitive data remains local to your infrastructure
- **📊 Status Reporting**: Easy monitoring of management status and logs

## 🏗️ Architecture

```
Your GitHub Fork → Proxmox Server → Local Management
     ↓                    ↓               ↓
Configuration       Git Clone       Auto-Apply
   Updates          + Local State   + Monitoring
```

### Components

1. **Repository Clone**: Your fork cloned to `/opt/proxmox-firewall`
2. **Terraform State**: Local state in `/opt/proxmox-firewall/terraform-state/`
3. **Management Scripts**: Automated update and status scripts
4. **Cron/Systemd**: Scheduled execution every 15 minutes
5. **Logging**: Comprehensive logs in `/var/log/proxmox-firewall/`

## 📋 Prerequisites

- **Proxmox VE server** with root access
- **GitHub fork** of the proxmox-firewall repository
- **SSH access** to the Proxmox server
- **Git authentication** configured (SSH keys or tokens)

## 🚀 Setup Process

### Step 1: Initial Setup on Proxmox Server

Run the setup script on your Proxmox server:

```bash
# Download the setup script
wget https://raw.githubusercontent.com/YOUR_USERNAME/proxmox-firewall/main/common/scripts/setup_local_management.sh

# Make it executable
chmod +x setup_local_management.sh

# Run setup with your repository and site name
./setup_local_management.sh https://github.com/YOUR_USERNAME/proxmox-firewall.git primary
```

### Step 2: Configure Environment Variables

Edit the environment configuration:

```bash
# Edit main environment file
nano /opt/proxmox-firewall/.env

# Edit site-specific overrides
nano /opt/proxmox-firewall/.env.primary
```

### Step 3: Verify Setup

Check that everything is working:

```bash
# Check status
/opt/proxmox-firewall/scripts/local_status.sh

# Run manual update
/opt/proxmox-firewall/scripts/local_update.sh

# Monitor logs
tail -f /var/log/proxmox-firewall/management.log
```

## 🔧 Configuration

### Environment Variables

The system uses cascading environment configuration:

1. **Base config**: `/opt/proxmox-firewall/.env`
2. **Site overrides**: `/opt/proxmox-firewall/.env.SITENAME`

#### Key Variables

```bash
# Site identification
CURRENT_SITE_NAME="primary"
TERRAFORM_STATE_PATH="/opt/proxmox-firewall/terraform-state/terraform.tfstate"

# Management settings
LOCAL_MANAGEMENT_ENABLED="true"
AUTO_UPDATE_ENABLED="true"
BACKUP_BEFORE_UPDATE="true"

# Logging
LOG_LEVEL="INFO"
LOG_FILE="/var/log/proxmox-firewall/management.log"
```

### Terraform State Backend

The system automatically configures Terraform to use local state:

```hcl
terraform {
  backend "local" {
    path = "/opt/proxmox-firewall/terraform-state/terraform.tfstate"
  }
}
```

### Git Authentication

For private repositories, configure SSH keys:

```bash
# Generate SSH key on Proxmox server
ssh-keygen -t ed25519 -C "proxmox-management@$(hostname)"

# Add public key to GitHub
cat ~/.ssh/id_ed25519.pub
# Copy this to GitHub → Settings → SSH Keys

# Test connection
ssh -T git@github.com
```

## 🔄 Operation

### Automatic Updates

The system automatically:

1. **Fetches** latest changes from your GitHub fork
2. **Backs up** current state before applying changes
3. **Runs security audit** to validate configuration
4. **Applies Ansible** maintenance playbook
5. **Updates Terraform** resources if needed
6. **Logs** all activities with timestamps

### Manual Operations

#### Check Status
```bash
/opt/proxmox-firewall/scripts/local_status.sh
```

#### Force Update
```bash
/opt/proxmox-firewall/scripts/local_update.sh
```

#### View Logs
```bash
# Recent activity
tail -20 /var/log/proxmox-firewall/management.log

# Follow live updates
tail -f /var/log/proxmox-firewall/management.log

# Search for errors
grep ERROR /var/log/proxmox-firewall/management.log
```

## 📊 Monitoring

### Status Dashboard

The status script provides comprehensive information:

```bash
/opt/proxmox-firewall/scripts/local_status.sh
```

Example output:
```
=== Proxmox Firewall Local Management Status ===

📁 Repository Status:
  Current commit: a1b2c3d
  Branch: main
  Last update: 2 hours ago (John Doe)

✅ Repository is up to date

🏗️  Terraform State:
  State file size: 45678 bytes
  Managed resources: 12

📋 Recent Activity (last 10 lines):
  [2025-01-15 10:15:01] === Starting local update process ===
  [2025-01-15 10:15:02] No updates available
  [2025-01-15 10:30:01] === Starting local update process ===
  [2025-01-15 10:30:03] Updates detected: a1b2c3d -> e4f5g6h
  [2025-01-15 10:30:05] Backup created: /opt/proxmox-firewall-backups/backup-20250115-103005.tar.gz
  [2025-01-15 10:30:08] Running security audit...
  [2025-01-15 10:30:10] Ansible maintenance completed successfully
  [2025-01-15 10:30:15] No Terraform changes needed
  [2025-01-15 10:30:16] === Local update process completed successfully ===
```

### System Integration

#### Systemd Status
```bash
# Check timer status
systemctl status proxmox-firewall-update.timer

# View recent runs
systemctl list-timers proxmox-firewall-update.timer

# Check service logs
journalctl -u proxmox-firewall-update.service
```

#### Cron Status
```bash
# View cron jobs
crontab -l | grep proxmox-firewall

# Check cron logs
grep proxmox-firewall /var/log/syslog
```

## 🔒 Security Considerations

### State File Protection

- Terraform state stored in `/opt/proxmox-firewall/terraform-state/` with 700 permissions
- Contains sensitive infrastructure data - never commit to git
- Regular backups to `/opt/proxmox-firewall-backups/`

### Git Repository Security

- Repository cloned to `/opt/proxmox-firewall` with 750 permissions
- SSH keys used for authentication (never use passwords)
- Automatic security audit before applying changes

### Access Control

- All operations run as root user
- Log files accessible to admin users
- Sensitive data never logged in plaintext

## 🛠️ Troubleshooting

### Common Issues

#### Git Authentication Fails
```bash
# Check SSH key configuration
ssh -T git@github.com

# Verify key is added to GitHub
cat ~/.ssh/id_ed25519.pub

# Test repository access
git ls-remote git@github.com:YOUR_USERNAME/proxmox-firewall.git
```

#### Terraform State Issues
```bash
# Check state file
ls -la /opt/proxmox-firewall/terraform-state/

# Validate state
cd /opt/proxmox-firewall/common/terraform
terraform validate

# Refresh state
terraform refresh
```

#### Update Process Fails
```bash
# Check recent logs
tail -50 /var/log/proxmox-firewall/management.log

# Run manual update with debug
cd /opt/proxmox-firewall
bash -x scripts/local_update.sh
```

### Recovery Procedures

#### Restore from Backup
```bash
# List available backups
ls -la /opt/proxmox-firewall-backups/

# Restore from backup
cd /opt/proxmox-firewall
tar -xzf /opt/proxmox-firewall-backups/backup-YYYYMMDD-HHMMSS.tar.gz
```

#### Reset Local Management
```bash
# Stop automatic updates
systemctl stop proxmox-firewall-update.timer

# Clean and re-setup
rm -rf /opt/proxmox-firewall
./setup_local_management.sh https://github.com/YOUR_USERNAME/proxmox-firewall.git primary
```

## 📈 Best Practices

### Repository Management

1. **Keep your fork updated** with upstream changes
2. **Use feature branches** for experimental changes
3. **Test changes** in development before merging to main
4. **Tag releases** for important milestones

### Configuration Management

1. **Update environment variables** through git (not directly on server)
2. **Use site-specific overrides** for local customizations
3. **Document changes** in commit messages
4. **Review logs** regularly for issues

### Security Practices

1. **Rotate SSH keys** periodically
2. **Monitor access logs** for unusual activity
3. **Keep backups** of Terraform state
4. **Audit permissions** on sensitive files

## 🔗 Integration

### CI/CD Integration

You can integrate the local management system with your development workflow:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Proxmox
on:
  push:
    branches: [main]
    
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Proxmox Update
        run: |
          # Proxmox will automatically pull changes within 15 minutes
          # Or trigger immediate update via SSH
          ssh proxmox-server "/opt/proxmox-firewall/scripts/local_update.sh"
```

### Monitoring Integration

Connect with monitoring systems:

```bash
# Export metrics for Prometheus
echo "proxmox_firewall_last_update $(stat -c %Y /opt/proxmox-firewall/.git/FETCH_HEAD)" > /var/lib/node_exporter/textfile_collector/proxmox_firewall.prom
```

## 📞 Support

For issues with local management:

1. **Check logs**: `/var/log/proxmox-firewall/management.log`
2. **Run diagnostics**: `/opt/proxmox-firewall/scripts/local_status.sh`
3. **Security audit**: `/opt/proxmox-firewall/common/scripts/security_audit.sh`
4. **GitHub Issues**: Report bugs or feature requests
5. **Community**: Join discussions for help and tips

---

**Next**: [Security Guidelines](SECURITY.md) | **Previous**: [Troubleshooting](TROUBLESHOOTING.md) 
