#!/bin/bash
# Ansible loader script for Proxmox Firewall
# This script runs local playbooks based on hostname and site configuration

# Set environment
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export ANSIBLE_CONFIG="/opt/proxmox-firewall/ansible/ansible.cfg"

# Log file setup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="/var/log/proxmox-firewall"
LOG_FILE="${LOG_DIR}/ansible_run_${TIMESTAMP}.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Get hostname to identify site
HOSTNAME=$(hostname)
SITE_NAME=${HOSTNAME%%[.-]*}  # Extract site name from hostname (first part before - or .)

echo "===== Starting Ansible run at $(date) =====" > "$LOG_FILE"
echo "Hostname: $HOSTNAME" >> "$LOG_FILE"
echo "Site Name: $SITE_NAME" >> "$LOG_FILE"

# Change to the Ansible directory
cd /opt/proxmox-firewall/ansible || {
    echo "ERROR: Ansible directory not found" >> "$LOG_FILE"
    exit 1
}

# Run the main maintenance playbook
echo "Running maintenance playbook..." >> "$LOG_FILE"
ansible-playbook playbooks/site_maintenance.yml -e "site_name=$SITE_NAME" >> "$LOG_FILE" 2>&1

# Clean up old log files (keep last 30 days)
find "$LOG_DIR" -name "ansible_run_*.log" -mtime +30 -delete

echo "===== Ansible run completed at $(date) =====" >> "$LOG_FILE"

# Report success/failure
if grep -q "failed=0" "$LOG_FILE"; then
    echo "Ansible run completed successfully" >> "$LOG_FILE"
    exit 0
else
    echo "Ansible run had failures, check $LOG_FILE for details" >> "$LOG_FILE"
    exit 1
fi
