# API Documentation

This document covers the various APIs and integration points available in the Proxmox Firewall project.

## 🚀 Overview

The Proxmox Firewall project provides several API interfaces for automation, monitoring, and integration:

- **Proxmox VE API**: VM management and infrastructure control
- **OPNsense API**: Firewall configuration and monitoring
- **Tailscale API**: VPN management and device control
- **Configuration API**: Site and device configuration management
- **Monitoring APIs**: Suricata, Zeek, and system metrics

## 🔧 Authentication

### API Token Management

Most APIs use token-based authentication. Tokens are managed through environment variables:

```bash
# Proxmox API tokens
export PROXMOX_API_SECRET="PVEAPIToken=user@realm!tokenid=secret-value"

# Tailscale API key
export TAILSCALE_API_KEY="tskey-api-..."

# OPNsense API credentials
export OPNSENSE_API_KEY="your-api-key"
export OPNSENSE_API_SECRET="your-api-secret"
```

### Generating API Tokens

**Proxmox VE:**
```bash
# Create API token via CLI
pveum user token add user@realm tokenid --expire 0

# Or via web interface: Datacenter -> Permissions -> API Tokens
```

**OPNsense:**
```bash
# Via web interface: System -> Access -> Users -> Edit user -> API keys
```

**Tailscale:**
```bash
# Via admin console: https://login.tailscale.com/admin/settings/keys
```

## 🖥️ Proxmox VE API

### Base URL and Authentication

```bash
BASE_URL="https://proxmox-host:8006/api2/json"
AUTH_HEADER="Authorization: PVEAPIToken=USER@REALM!TOKENID=SECRET"
```

### Common Operations

#### List VMs
```bash
curl -k -H "$AUTH_HEADER" \
  "$BASE_URL/nodes/NODE_NAME/qemu"
```

**Response:**
```json
{
  "data": [
    {
      "vmid": 100,
      "name": "opnsense-firewall",
      "status": "running",
      "cpu": 0.05,
      "mem": 2147483648,
      "maxmem": 4294967296
    }
  ]
}
```

#### Get VM Configuration
```bash
curl -k -H "$AUTH_HEADER" \
  "$BASE_URL/nodes/NODE_NAME/qemu/VMID/config"
```

#### Start/Stop VM
```bash
# Start VM
curl -k -X POST -H "$AUTH_HEADER" \
  "$BASE_URL/nodes/NODE_NAME/qemu/VMID/status/start"

# Stop VM
curl -k -X POST -H "$AUTH_HEADER" \
  "$BASE_URL/nodes/NODE_NAME/qemu/VMID/status/stop"
```

#### Create VM Snapshot
```bash
curl -k -X POST -H "$AUTH_HEADER" \
  -d "snapname=backup-$(date +%Y%m%d)" \
  "$BASE_URL/nodes/NODE_NAME/qemu/VMID/snapshot"
```

### Python Example

```python
import requests
import os

class ProxmoxAPI:
    def __init__(self, host, token):
        self.base_url = f"https://{host}:8006/api2/json"
        self.headers = {"Authorization": f"PVEAPIToken={token}"}
        self.session = requests.Session()
        self.session.verify = False  # For self-signed certs
    
    def get_vms(self, node):
        """Get list of VMs on a node"""
        response = self.session.get(
            f"{self.base_url}/nodes/{node}/qemu",
            headers=self.headers
        )
        return response.json()
    
    def vm_status(self, node, vmid):
        """Get VM status"""
        response = self.session.get(
            f"{self.base_url}/nodes/{node}/qemu/{vmid}/status/current",
            headers=self.headers
        )
        return response.json()
    
    def start_vm(self, node, vmid):
        """Start a VM"""
        response = self.session.post(
            f"{self.base_url}/nodes/{node}/qemu/{vmid}/status/start",
            headers=self.headers
        )
        return response.json()

# Usage
api = ProxmoxAPI("proxmox-host", os.getenv("PROXMOX_API_SECRET"))
vms = api.get_vms("pve")
print(f"Found {len(vms['data'])} VMs")
```

## 🔥 OPNsense API

### Authentication

OPNsense uses API key/secret pairs:

```bash
OPNSENSE_URL="https://opnsense-ip"
API_KEY="your-api-key"
API_SECRET="your-api-secret"
```

### Common Operations

#### Get System Information
```bash
curl -k -u "$API_KEY:$API_SECRET" \
  "$OPNSENSE_URL/api/core/system/status"
```

#### Get Firewall Rules
```bash
curl -k -u "$API_KEY:$API_SECRET" \
  "$OPNSENSE_URL/api/firewall/filter/searchRule"
```

#### Add Firewall Rule
```bash
curl -k -X POST -u "$API_KEY:$API_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "rule": {
      "enabled": "1",
      "interface": "lan",
      "direction": "in",
      "ipprotocol": "inet",
      "protocol": "tcp",
      "source_net": "10.1.10.0/24",
      "destination_net": "10.1.10.100",
      "destination_port": "445",
      "description": "Allow SMB access to NAS"
    }
  }' \
  "$OPNSENSE_URL/api/firewall/filter/addRule"
```

#### Get DHCP Leases
```bash
curl -k -u "$API_KEY:$API_SECRET" \
  "$OPNSENSE_URL/api/dhcpv4/leases/searchLease"
```

### Python Example

```python
import requests
import json

class OPNsenseAPI:
    def __init__(self, host, api_key, api_secret):
        self.base_url = f"https://{host}/api"
        self.auth = (api_key, api_secret)
        self.session = requests.Session()
        self.session.verify = False
    
    def get_system_status(self):
        """Get system status"""
        response = self.session.get(
            f"{self.base_url}/core/system/status",
            auth=self.auth
        )
        return response.json()
    
    def get_firewall_rules(self, interface=None):
        """Get firewall rules"""
        params = {"interface": interface} if interface else {}
        response = self.session.get(
            f"{self.base_url}/firewall/filter/searchRule",
            auth=self.auth,
            params=params
        )
        return response.json()
    
    def add_firewall_rule(self, rule_data):
        """Add a firewall rule"""
        response = self.session.post(
            f"{self.base_url}/firewall/filter/addRule",
            auth=self.auth,
            json={"rule": rule_data}
        )
        return response.json()

# Usage
api = OPNsenseAPI("10.1.10.1", "api_key", "api_secret")
status = api.get_system_status()
print(f"System uptime: {status['uptime']}")
```

## 🌐 Tailscale API

### Authentication

Tailscale uses API keys for authentication:

```bash
TAILSCALE_API_KEY="tskey-api-..."
TAILNET="your-tailnet"
```

### Common Operations

#### List Devices
```bash
curl -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/$TAILNET/devices"
```

#### Get Device Details
```bash
curl -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/device/DEVICE_ID"
```

#### Update Device Settings
```bash
curl -X POST -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "opnsense-firewall",
    "advertiseRoutes": ["10.1.0.0/16"],
    "advertiseExitNode": true
  }' \
  "https://api.tailscale.com/api/v2/device/DEVICE_ID"
```

#### Get ACL Policy
```bash
curl -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl"
```

### Python Example

```python
import requests

class TailscaleAPI:
    def __init__(self, api_key, tailnet):
        self.api_key = api_key
        self.tailnet = tailnet
        self.base_url = "https://api.tailscale.com/api/v2"
        self.headers = {"Authorization": f"Bearer {api_key}"}
    
    def list_devices(self):
        """List all devices in the tailnet"""
        response = requests.get(
            f"{self.base_url}/tailnet/{self.tailnet}/devices",
            headers=self.headers
        )
        return response.json()
    
    def get_device(self, device_id):
        """Get details for a specific device"""
        response = requests.get(
            f"{self.base_url}/device/{device_id}",
            headers=self.headers
        )
        return response.json()
    
    def update_device(self, device_id, settings):
        """Update device settings"""
        response = requests.post(
            f"{self.base_url}/device/{device_id}",
            headers=self.headers,
            json=settings
        )
        return response.json()

# Usage
api = TailscaleAPI("tskey-api-...", "example.com")
devices = api.list_devices()
for device in devices["devices"]:
    print(f"Device: {device['name']} - {device['addresses'][0]}")
```

## ⚙️ Configuration API

### Site Configuration Management

The project includes custom APIs for managing site configurations:

#### Load Site Configuration
```python
from config.site_loader import SiteConfigLoader

loader = SiteConfigLoader()
site_config = loader.load_site("primary")
print(f"Network prefix: {site_config['site']['network_prefix']}")
```

#### Validate Configuration
```bash
# Via script
./validate-config.sh site-name

# Via Python
python -c "
from config.validator import ConfigValidator
validator = ConfigValidator()
result = validator.validate_site('config/sites/primary.yml')
print('Valid!' if result.is_valid else f'Errors: {result.errors}')
"
```

#### Generate Terraform Variables
```python
from config.terraform_vars import TerraformVarGenerator

generator = TerraformVarGenerator()
tf_vars = generator.generate_for_site("primary")
print(tf_vars)
```

### Device Configuration API

#### List Devices for Site
```bash
find config/devices/SITE_NAME/ -name "*.yml" -exec basename {} .yml \;
```

#### Load Device Configuration
```python
from config.device_loader import DeviceConfigLoader

loader = DeviceConfigLoader()
device_config = loader.load_device("primary", "nas")
print(f"Device IP: {device_config['network']['ip_address']}")
```

## 📊 Monitoring APIs

### Suricata API

#### Get Alert Statistics
```bash
# Via OPNsense API
curl -k -u "$API_KEY:$API_SECRET" \
  "$OPNSENSE_URL/api/ids/settings/getAlertInfo"
```

#### Get Recent Alerts
```bash
# Direct log access
tail -n 100 /var/log/suricata/eve.json | jq '.alert'
```

### Zeek API

#### Get Connection Logs
```bash
# Via Zeek log files
zeek-cut ts id.orig_h id.resp_h id.resp_p proto service < /opt/zeek/logs/current/conn.log
```

#### Query Zeek Logs with Python
```python
import json

def parse_zeek_logs(log_file):
    """Parse Zeek JSON logs"""
    connections = []
    with open(log_file, 'r') as f:
        for line in f:
            try:
                log_entry = json.loads(line)
                if log_entry.get('_path') == 'conn':
                    connections.append({
                        'timestamp': log_entry.get('ts'),
                        'source': log_entry.get('id.orig_h'),
                        'destination': log_entry.get('id.resp_h'),
                        'port': log_entry.get('id.resp_p'),
                        'bytes': log_entry.get('resp_bytes', 0)
                    })
            except json.JSONDecodeError:
                continue
    return connections

# Usage
connections = parse_zeek_logs('/opt/zeek/logs/current/conn.log')
large_transfers = [c for c in connections if c['bytes'] > 1000000]
print(f"Found {len(large_transfers)} large data transfers")
```

## 🔌 Webhook Integration

### Setting Up Webhooks

#### Prometheus AlertManager Integration
```yaml
# alertmanager.yml
route:
  receiver: 'proxmox-firewall-webhook'

receivers:
- name: 'proxmox-firewall-webhook'
  webhook_configs:
  - url: 'http://monitoring-server:9093/webhook/proxmox-firewall'
    send_resolved: true
```

#### Custom Webhook Handler
```python
from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

@app.route('/webhook/proxmox-firewall', methods=['POST'])
def handle_alert():
    alert_data = request.json
    
    # Process alert
    if alert_data['status'] == 'firing':
        # Handle active alert
        severity = alert_data.get('commonLabels', {}).get('severity', 'unknown')
        if severity == 'critical':
            # Trigger emergency response
            emergency_lockdown()
    
    return jsonify({'status': 'processed'})

def emergency_lockdown():
    """Emergency lockdown procedure"""
    # Block all non-essential traffic
    # Notify administrators
    # Log incident
    pass

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9093)
```

## 🛠️ Automation Examples

### Automated Backup Script
```python
#!/usr/bin/env python3
import os
import sys
from datetime import datetime
from proxmox_api import ProxmoxAPI

def backup_vms():
    """Automated VM backup"""
    api = ProxmoxAPI("proxmox-host", os.getenv("PROXMOX_API_SECRET"))
    
    # Get all VMs
    vms = api.get_vms("pve")
    
    for vm in vms['data']:
        vmid = vm['vmid']
        name = vm['name']
        
        # Create snapshot
        snapshot_name = f"auto-backup-{datetime.now().strftime('%Y%m%d-%H%M')}"
        
        try:
            result = api.create_snapshot("pve", vmid, snapshot_name)
            print(f"Created snapshot for {name} (VMID: {vmid})")
        except Exception as e:
            print(f"Failed to backup {name}: {e}")

if __name__ == "__main__":
    backup_vms()
```

### Network Health Monitor
```python
#!/usr/bin/env python3
import time
import requests
from opnsense_api import OPNsenseAPI
from tailscale_api import TailscaleAPI

def monitor_network_health():
    """Monitor network health across all components"""
    opnsense = OPNsenseAPI("10.1.10.1", "api_key", "api_secret")
    tailscale = TailscaleAPI("tskey-api-...", "example.com")
    
    while True:
        # Check OPNsense status
        try:
            status = opnsense.get_system_status()
            if status['temperature'] > 70:
                print("WARNING: OPNsense temperature high!")
        except Exception as e:
            print(f"OPNsense check failed: {e}")
        
        # Check Tailscale connectivity
        try:
            devices = tailscale.list_devices()
            offline_devices = [d for d in devices['devices'] if not d['online']]
            if offline_devices:
                print(f"WARNING: {len(offline_devices)} Tailscale devices offline")
        except Exception as e:
            print(f"Tailscale check failed: {e}")
        
        time.sleep(300)  # Check every 5 minutes

if __name__ == "__main__":
    monitor_network_health()
```

## 📋 Rate Limits and Best Practices

### API Rate Limits

| API | Rate Limit | Notes |
|-----|------------|-------|
| Proxmox VE | 100 req/min | Per API token |
| OPNsense | 60 req/min | Per API key |
| Tailscale | 100 req/min | Per API key |

### Best Practices

1. **Use Connection Pooling**: Reuse HTTP connections
2. **Implement Retry Logic**: Handle temporary failures
3. **Cache Responses**: Avoid redundant API calls
4. **Use Webhooks**: For real-time notifications
5. **Monitor API Usage**: Track rate limit consumption
6. **Secure Credentials**: Use environment variables or secure vaults

### Error Handling Example
```python
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_robust_session():
    """Create HTTP session with retry logic"""
    session = requests.Session()
    
    # Configure retry strategy
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    return session
```

---

For additional API examples and integrations, see the `examples/` directory in the repository. 
