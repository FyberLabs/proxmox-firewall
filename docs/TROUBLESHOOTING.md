# Troubleshooting Guide

This guide covers common issues and their solutions for the Proxmox Firewall project.

## 🚀 Quick Diagnostics

### System Health Check
```bash
# Run comprehensive validation
./validate-config.sh

# Check Ansible connectivity
ansible all -m ping -i deployment/ansible/inventory/

# Test configuration syntax
yamllint config/sites/
ansible-lint deployment/ansible/
```

### Service Status Check
```bash
# Check Proxmox services
systemctl status pve-cluster pveproxy pvedaemon

# Check network interfaces
ip link show
bridge link show

# Check VMs
qm list
```

## 🔧 Installation Issues

### Prerequisites Installation Fails

**Problem**: `./deployment/scripts/prerequisites.sh` fails with package errors

**Solution**:
```bash
# Update package lists
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# Install manually if needed
sudo apt install python3-pip ansible terraform

# Check Python environment
python3 --version
pip3 --version
```

### SSH Key Issues

**Problem**: "Permission denied (publickey)" errors

**Solution**:
```bash
# Check SSH key permissions
ls -la ~/.ssh/
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Test SSH connection
ssh -v user@proxmox-host

# Add key to agent
ssh-add ~/.ssh/id_rsa

# Verify key in .env file
grep SSH .env
```

### Ansible Connection Failures

**Problem**: Ansible can't connect to Proxmox hosts

**Common Causes & Solutions**:

1. **SSH Key Not Configured**:
   ```bash
   # Copy SSH key to target host
   ssh-copy-id root@proxmox-host
   
   # Or manually add to authorized_keys
   cat ~/.ssh/id_rsa.pub | ssh root@proxmox-host 'cat >> ~/.ssh/authorized_keys'
   ```

2. **Wrong Inventory Configuration**:
   ```yaml
   # Check deployment/ansible/inventory/hosts.yml
   all:
     hosts:
       proxmox-host:
         ansible_host: 192.168.1.100
         ansible_user: root
         ansible_ssh_private_key_file: ~/.ssh/id_rsa
   ```

3. **Firewall Blocking SSH**:
   ```bash
   # Check if SSH port is open
   nmap -p 22 proxmox-host
   
   # Allow SSH through firewall
   ufw allow 22
   ```

## 🌐 Network Configuration Issues

### VLAN Configuration Problems

**Problem**: VLANs not working correctly

**Diagnostics**:
```bash
# Check VLAN configuration
cat /etc/network/interfaces

# Test VLAN connectivity
ping -I vlan10 10.1.10.1

# Check bridge configuration
brctl show
```

**Solution**:
```bash
# Restart networking
systemctl restart networking

# Recreate VLANs if needed
ansible-playbook deployment/ansible/playbooks/03_network_setup.yml
```

### IP Address Conflicts

**Problem**: IP address conflicts causing connectivity issues

**Diagnostics**:
```bash
# Check for duplicate IPs
nmap -sn 10.1.10.0/24

# Check ARP table
arp -a

# Verify DHCP leases
cat /var/lib/dhcp/dhcpd.leases
```

**Solution**:
1. Update site configuration with unique network prefixes
2. Clear DHCP leases: `rm /var/lib/dhcp/dhcpd.leases`
3. Restart network services

### Bridge Interface Issues

**Problem**: Network bridges not working

**Diagnostics**:
```bash
# Check bridge status
brctl show
ip link show type bridge

# Check bridge forwarding
cat /proc/sys/net/bridge/bridge-nf-call-iptables
```

**Solution**:
```bash
# Recreate bridges
ansible-playbook deployment/ansible/playbooks/03_network_setup.yml --tags bridges

# Enable bridge forwarding
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
```

## 🖥️ VM Deployment Issues

### Terraform Failures

**Problem**: Terraform can't create VMs

**Common Issues**:

1. **Invalid API Credentials**:
   ```bash
   # Test API access
   curl -k https://proxmox-host:8006/api2/json/version \
     -H "Authorization: PVEAPIToken=USER@REALM!TOKENID=SECRET"
   
   # Check .env file
   grep PROXMOX_API .env
   ```

2. **Insufficient Storage**:
   ```bash
   # Check storage usage
   pvesm status
   df -h
   
   # Clean up old VMs/templates
   qm list
   qm destroy VMID
   ```

3. **Template Missing**:
   ```bash
   # List templates
   qm list | grep template
   
   # Recreate templates
   ansible-playbook deployment/ansible/playbooks/04_vm_templates.yml
   ```

### VM Won't Start

**Problem**: VMs fail to start

**Diagnostics**:
```bash
# Check VM configuration
qm config VMID

# Check VM logs
journalctl -u qemu-server@VMID

# Check storage
qm list
pvesm status
```

**Solution**:
```bash
# Start VM manually
qm start VMID

# Reset VM if corrupted
qm reset VMID

# Check hardware settings
qm set VMID --memory 4096 --cores 2
```

### Cloud-Init Issues

**Problem**: Cloud-init configuration not applying

**Diagnostics**:
```bash
# Check cloud-init status in VM
cloud-init status

# View cloud-init logs
journalctl -u cloud-init

# Check user-data
cat /var/lib/cloud/instance/user-data.txt
```

**Solution**:
```bash
# Regenerate cloud-init
qm set VMID --cicustom user=local:snippets/user-data.yml

# Clean cloud-init cache
cloud-init clean

# Force cloud-init run
cloud-init init --local
```

## 🔥 OPNsense Configuration Issues

### Can't Access OPNsense Web Interface

**Problem**: Unable to connect to OPNsense web UI

**Diagnostics**:
```bash
# Check if VM is running
qm status VMID

# Check network connectivity
ping opnsense-ip

# Check if web interface is listening
nmap -p 80,443 opnsense-ip
```

**Solution**:
```bash
# Access via console
qm terminal VMID

# Reset web interface
# In OPNsense console: Option 12 -> Reset web interface

# Check firewall rules
# In OPNsense: Firewall -> Rules -> LAN
```

### Firewall Rules Not Working

**Problem**: Traffic not being blocked/allowed as expected

**Diagnostics**:
```bash
# Check firewall logs
tail -f /var/log/filter.log

# Test connectivity
nc -zv target-ip target-port

# Check rule order
# In OPNsense GUI: Firewall -> Rules
```

**Solution**:
1. Verify rule order (rules are processed top to bottom)
2. Check source/destination specifications
3. Ensure interfaces are correct
4. Clear firewall states: Diagnostics -> States -> Reset States

### DHCP Server Issues

**Problem**: DHCP not assigning addresses

**Diagnostics**:
```bash
# Check DHCP service
service dhcpd status

# Check DHCP configuration
cat /var/dhcpd/etc/dhcpd.conf

# Monitor DHCP logs
tail -f /var/log/dhcpd.log
```

**Solution**:
```bash
# Restart DHCP service
service dhcpd restart

# Check IP pool availability
# In OPNsense: Services -> DHCPv4 -> [Interface]

# Clear DHCP leases
# Services -> DHCPv4 -> Leases -> Clear all
```

## 🔐 VPN and Security Issues

### Tailscale Connection Problems

**Problem**: Tailscale VPN not connecting

**Diagnostics**:
```bash
# Check Tailscale status
tailscale status

# Check Tailscale logs
journalctl -u tailscaled

# Test connectivity
tailscale ping peer-name
```

**Solution**:
```bash
# Re-authenticate
tailscale up --reset

# Check firewall rules for UDP 41641
iptables -L | grep 41641

# Restart Tailscale
systemctl restart tailscaled
```

### Suricata Not Detecting Threats

**Problem**: IDS/IPS not generating alerts

**Diagnostics**:
```bash
# Check Suricata status
systemctl status suricata

# Check rule updates
suricata-update list-enabled-sources

# Test rule detection
curl http://testmyids.com
```

**Solution**:
```bash
# Update rules
suricata-update

# Restart Suricata
systemctl restart suricata

# Check configuration
suricata -T -c /etc/suricata/suricata.yaml
```

### Certificate Issues

**Problem**: SSL/TLS certificate errors

**Diagnostics**:
```bash
# Check certificate validity
openssl x509 -in cert.pem -text -noout

# Test SSL connection
openssl s_client -connect hostname:443

# Check certificate chain
curl -I https://hostname
```

**Solution**:
```bash
# Regenerate certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365

# Update certificate in OPNsense
# System -> Trust -> Certificates -> Add

# Restart web service
service nginx restart
```

## 💾 Backup and Storage Issues

### Backup Failures

**Problem**: Proxmox backups failing

**Diagnostics**:
```bash
# Check backup storage
pvesm status

# Check backup logs
journalctl -u pve-daily-update

# List backups
pvesh get /nodes/NODE/storage/STORAGE/content --content backup
```

**Solution**:
```bash
# Clean old backups
vzdump --cleanup 1

# Check storage permissions
ls -la /var/lib/vz/dump/

# Test backup manually
vzdump VMID --storage local --compress gzip
```

### Storage Full

**Problem**: Storage space exhausted

**Diagnostics**:
```bash
# Check disk usage
df -h
pvesm status

# Find large files
du -sh /* | sort -hr | head -10

# Check VM disk usage
qm list
```

**Solution**:
```bash
# Clean old backups
find /var/lib/vz/dump/ -mtime +7 -delete

# Remove unused VM disks
qm disk unlink VMID virtio0

# Add storage
pvesm add dir NEW-STORAGE --path /mnt/storage
```

## 🧪 Testing and Validation Issues

### Test Suite Failures

**Problem**: Integration tests failing

**Diagnostics**:
```bash
# Run tests with verbose output
cd docker-test-framework
./run-integration-tests.sh -t example -v

# Check Docker status
docker ps -a
docker logs container-name
```

**Solution**:
```bash
# Clean Docker environment
docker system prune -a

# Rebuild test environment
docker-compose down
docker-compose up --build

# Check test configuration
cat docker-test-framework/example-site.yml
```

### Configuration Validation Errors

**Problem**: `validate-config.sh` reports errors

**Common Issues**:

1. **YAML Syntax Errors**:
   ```bash
   # Check YAML syntax
   yamllint config/sites/site.yml
   
   # Fix common issues: indentation, missing quotes
   ```

2. **Missing Required Fields**:
   ```bash
   # Check required configuration
   grep -r "required" config/
   
   # Add missing fields to site configuration
   ```

3. **Invalid Network Configuration**:
   ```bash
   # Validate network ranges
   ipcalc 10.1.0.0/16
   
   # Check for conflicts
   grep -r "10.1" config/
   ```

## 📞 Getting Additional Help

### Log Collection

When reporting issues, collect relevant logs:

```bash
# Create support bundle
mkdir support-logs
cp /var/log/syslog support-logs/
cp ~/.ansible.log support-logs/ 2>/dev/null
journalctl -u pveproxy > support-logs/pveproxy.log
tar czf support-$(date +%Y%m%d).tar.gz support-logs/
```

### System Information

Include system details:

```bash
# System info
uname -a
lsb_release -a
free -m
df -h

# Network info
ip addr show
ip route show

# Service status
systemctl status pveproxy pvedaemon pve-cluster
```

### Community Support

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and community help
- **Documentation**: Check all files in `docs/` directory
- **Examples**: Review `docker-test-framework/example-*` configs

---

If you can't find a solution here, please create a GitHub issue with:
1. Problem description
2. Steps to reproduce
3. Expected vs actual behavior
4. System information
5. Relevant logs 
