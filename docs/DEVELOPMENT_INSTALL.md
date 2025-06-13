# Development & Testing Installation Guide (Manual Fork)

> **This guide is for development and testing only. For production use, always use the template/submodule approach described in the main README.**

## Manual Forking & Direct Repo Setup

### 0. Environment Variables

```bash
cp env.example .env
```
Edit the `.env` file to set variables for the custom proxmox iso and variables for ansible.

### 1. Install Prerequisites

```bash
# First: Fork this repository on GitHub to YOUR-USERNAME/proxmox-firewall
# Then clone YOUR fork (not the original):
git clone https://github.com/YOUR-USERNAME/proxmox-firewall.git
cd proxmox-firewall

# Set up your fork with correct URLs:
./scripts/setup-fork.sh YOUR-USERNAME

# Install required packages and Python dependencies
./deployment/scripts/prerequisites.sh
```

### 2. Download Latest Images

```bash
./deployment/scripts/download_latest_images.sh
```

### 3. Configure Sites

```bash
./deployment/scripts/create_site_config.sh
```

### 4. Configure Devices

```bash
./deployment/scripts/add_device.sh
```

### 5. Customize Site and Device Configurations
- Edit site configurations in `config/sites/<site_name>.yml`
- Modify device configurations in `config/devices/<site_name>/`
- Update `.env` file with credentials and MAC addresses

```bash
# Validate your configuration before deployment
./validate-config.sh <site_name>
```

### 6. Create Custom Proxmox ISO

```bash
ansible-playbook deployment/ansible/playbooks/create_proxmox_iso.yml
```

### 7. Deploy Proxmox

```bash
sudo dd if=proxmox-custom.iso of=/dev/sdX bs=4M status=progress conv=fsync
# Boot from USB and install Proxmox
```

### 8. Fetch Credentials

```bash
./common/scripts/fetch_credentials.sh <site_name>
```

### 9. Deploy Infrastructure and Configuration

**For CI/Testing and Initial Validation:**
```bash
./validate-config.sh <site_name>
ansible-playbook deployment/ansible/master_playbook.yml --limit=<site_name>
```

**For Production Deployment:**
```bash
cd proxmox-local/ansible
ansible-playbook site.yml --limit=<site_name>
```

---

> **Reminder: This workflow is for development and testing only. For production, use the template/submodule approach.** 
