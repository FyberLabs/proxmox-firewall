# Proxmox Firewall Deployment Plan

## Network Configuration
### Port Assignments
- **10G SFP+ Ports**:
  - `vmbr0` (LAN): VLAN 10, 30, 40, 50.
  - `vmbr2` (Cameras): VLAN 20.
- **2.5G Ports**:
  - `vmbr1` (Primary WAN - Fiber).
  - `vmbr3` (Failover WAN - Starlink).

### VLANs
- **Tennessee**:
  - VLAN 10 (LAN): `10.1.10.0/24`
  - VLAN 20 (Cameras): `10.1.20.0/24`
  - VLAN 50 (Management): `10.1.50.0/24`
- **Primary Home**:
  - VLAN 10 (LAN): `10.2.10.0/24`
  - VLAN 20 (Cameras): `10.2.20.0/24`
  - VLAN 50 (Management): `10.2.50.0/24`

## VM Templates
1. **Ubuntu Omada Controller**:
   - Cloud image: `jammy-server-cloudimg-amd64.img`.
   - Pre-installed: `qemu-guest-agent`, OpenJDK 17.
   - Proxmox Template ID: `9001`.

2. **Tailscale VM**:
   - Lightweight Ubuntu/Alpine.
   - Subnet routes: `10.1.0.0/16`, `10.2.0.0/16`.

## Automation
### Terraform
- Resources for `omada-controller` and `tailscale-vm`.
- Secrets sourced from `.env`:
  ```plaintext
  PROXMOX_API_SECRET="..."
  TAILSCALE_AUTH_KEY="..."
  ```

### Ansible
- Playbooks for:
  - Omada Controller setup.
  - Tailscale configuration.

## Firewall Rules
- **WAN**: Failover rules for `vmbr1` (fiber) and `vmbr3` (Starlink).
- **Cameras**: Restrict `vmbr2` to NVR/Home Assistant.

## Files to Generate
1. `.env`: Secrets storage.
2. `create_custom_iso.sh`: ISO modification script.
3. `terraform/`: Terraform configurations.
4. `ansible/`: Ansible playbooks.
