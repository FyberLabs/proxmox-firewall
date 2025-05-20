# proxmox-firewall

[Proxmox](https://pve.proxmox.com/wiki/Installation) based firewall with OPNSense, tailscale, Omada controller, and Suricata

## Hardware

- CPU N100 to N305
- Memory 8GB-16GB
- Hard drive 128-512GB SSD
- 3-4 I226v 2.5GBps Ethernet
- 2 SFP+

## Promox bare metal install

- Proxmox ISOs: [Download](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso)
- Modify Proxmox VE ISO with /etc/pve/datacenter.cfg

### Tasks

- Create Proxmox ISO with answer file
- Run ansible playbooks to configure proxmox, network, deploy VMs by terraform, etc.

### VMs

- OPNSense with tailscale, vtnet network devices
  - Assign 4 CPU cores, 4-6GB RAM, and a 64GB virtual disk.
  - Advice for networking OPNSense on Proxmox: (https://forum.opnsense.org/index.php?topic=44159.0)
  - Install Tailscale in the OPNsense VM for direct VPN routing. Use the Tailscale FreeBSD package and configure it to connect between firewalls
- Omada Controller
  - Use a privileged LXC container with 1 CPU core, 1-2GB RAM, and a 10-20GB disk
- Suricata IDS/IPS
  - Integrated directly into OPNsense for real-time traffic inspection
  - Monitors both WAN interfaces (fiber and Starlink)
  - Uses emerging threats ruleset for threat detection
- Zeek Network Security Monitor
  - Dedicated VM with 2 CPU cores, 4GB RAM, and 50GB disk
  - Passive monitoring of WAN interfaces via promiscuous mode
  - Advanced network traffic analysis and threat hunting
  - Web dashboard for log analysis

#### Network

- Setup:
  - Create a Linux bridge (vmbr0) in Proxmox for LAN (e.g., 10Gb SFP+ port) and another (vmbr1) for WAN (e.g., 2.5GbE port). Ensure the Proxmox management interface is on a separate VLAN (e.g., VLAN1) to avoid WAN exposure.
  - Use VirtIO NICs for the OPNsense VM, attaching them to vmbr0 (LAN) and vmbr1 (WAN). Enable VLAN tagging in OPNsense for your IP scheme (e.g., 10.1.0.0/16 for Tennessee, 10.2.0.0/16 for primary home).
  - Configure the Omada controller LXC with a VirtIO NIC on vmbr0 for LAN access to manage APs/Decos.

## Firewall configuration

Given the near-identical setups (10Gbps fiber, Starlink backup, Omada WiFi 7 APs, Reolink cameras, Home Assistant, and a single NAS in the primary home with plans for a second in Tennessee), the rules will focus on protecting your network, allowing necessary cross-home access (e.g., to the NAS, Home Assistant, and Omada controller), and isolating sensitive VLANs (e.g., cameras, IoT, guest). I'll provide recommended firewall rules for both homes, tailored to the10net IP addressing scheme(10.1.0.0/16 for Tennessee, 10.2.0.0/16 for Primary Home) and Tailscale's100.64.0.0/10VPN range, ensuring no IP conflicts and secure communication.

Network Context

- IP Ranges(from the previous IP range diagram):

  - Tennessee:

    - VLAN 10 (Main LAN): 10.1.10.0/24 (e.g., Home Assistant: 10.1.10.10, future NAS: 10.1.10.100)
    - VLAN 20 (Cameras): 10.1.20.0/24 (Reolink Pro Hub: 10.1.20.2, NVR: 10.1.20.3)
    - VLAN 30 (IoT): 10.1.30.0/24
    - VLAN 40 (Guest): 10.1.40.0/24
    - VLAN 50 (Management): 10.1.50.0/24 (Omada Controller: 10.1.50.2)
  - Primary Home:

    - VLAN 10 (Main LAN): 10.2.10.0/24 (Home Assistant: 10.2.10.10, NAS: 10.2.10.100, Desktops: 10.2.10.101–110)
    - VLAN 20 (Cameras): 10.2.20.0/24 (Reolink Pro Hub: 10.2.20.2, NVR: 10.2.20.3)
    - VLAN 30 (IoT): 10.2.30.0/24
    - VLAN 40 (Guest): 10.2.40.0/24
    - VLAN 50 (Management): 10.2.50.0/24 (Omada Controller: 10.2.50.2)
  - Tailscale: 100.64.0.0/10 (e.g., Tennessee OPNSense: 100.64.1.1, Primary Home NAS: 100.64.1.4)
- Goals:

  - Allow Tennessee devices (VLAN 10) to access the Primary Home NAS (10.2.10.100) via SMB/NFS.
  - Permit Omada controller (10.1.50.2 or 10.2.50.2) to manage APs across both homes.
  - Enable Home Assistant access (10.1.10.10, 10.2.10.10) across sites.
  - Restrict camera VLAN (20) to local NVR and limited remote access.
  - Isolate IoT (VLAN 30) and Guest (VLAN 40) from sensitive resources.
  - Allow Tailscale VPN traffic (UDP 41641) and ensure Starlink compatibility.
- Assumptions:

  - Both OPNSense firewalls handle 10Gbps fiber and Starlink WANs.
  - Tailscale is configured with subnet routing for 10.1.x.x and 10.2.x.x.
  - Devices use static IPs where specified; others use DHCP (e.g., 10.1.10.100–254).

General Firewall Rule Principles

- Default Deny: OPNSense blocks all traffic unless explicitly allowed.
- VLAN Segregation: Restrict inter-VLAN access unless necessary (e.g., IoT can't access Main LAN).
- Tailscale Security: Use Tailscale ACLs alongside OPNSense rules for layered protection.
- Minimal Exposure: Allow only required ports/protocols (e.g., 445 for SMB, 8123 for Home Assistant).
- Logging: Enable logging for troubleshooting but disable for high-traffic rules to reduce load.

Recommended Firewall Rules

Below are the firewall rules for each home, organized by interface (WAN, VLAN 10, VLAN 20, VLAN 30, VLAN 40, VLAN 50). Rules are designed to be symmetric where possible, with adjustments for the NAS in the Primary Home and WiFi-only devices in Tennessee.

Tennessee Vacation Home Firewall Rules

Interface: WAN

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|Any|Any|UDP/41641|Allow Tailscale VPN traffic (WireGuard)|
|2|Allow|Any|10.1.50.2|TCP/8088,8043|Omada Controller remote access (optional, restrict to VPN)|
|3|Allow|Any|10.1.10.10|TCP/8123|Home Assistant remote access (optional, prefer VPN)|
|4|Block|Any|Any|Any|Default deny (implicit)|

- Notes:

  - UDP 41641 is critical for Tailscale's WireGuard connections, especially with Starlink's CGNAT.
  - Remote Omada/Home Assistant access is optional; prefer Tailscale VPN (100.64.x.x) for security.

Interface: VLAN 10 (Main LAN, 10.1.10.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.1.10.0/24|10.2.10.100|TCP/445,2049|Access Primary Home NAS (SMB/NFS)|
|2|Allow|10.1.10.0/24|10.2.10.10|TCP/8123|Access Primary Home Assistant|
|3|Allow|10.1.10.0/24|10.1.50.2|TCP/8088,8043, UDP/27001, TCP/29810-29814|Local Omada Controller|
|4|Allow|10.1.10.0/24|10.2.50.2|TCP/8088,8043, UDP/27001, TCP/29810-29814|Primary Home Omada Controller (if managing cross-home)|
|5|Allow|10.1.10.0/24|Any|TCP/80,443|Internet access (HTTP/HTTPS)|
|6|Allow|10.1.10.0/24|10.1.30.0/24|Any|Access IoT VLAN (e.g., for Home Assistant)|
|7|Block|10.1.10.0/24|10.1.20.0/24|Any|Block access to Camera VLAN|
|8|Block|10.1.10.0/24|10.1.40.0/24|Any|Block access to Guest VLAN|

- Notes:

  - Allows WiFi laptops to access the Primary Home NAS and Home Assistant over Tailscale-routed subnets.
  - Omada ports are for AP management; cross-home access is optional (e.g., one controller managing both sites).
  - Internet access is unrestricted for VLAN 10 but can be filtered (e.g., DNS via Pi-hole).
  - IoT access is allowed for Home Assistant integration; cameras and guests are isolated.

Interface: VLAN 20 (Cameras, 10.1.20.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.1.20.0/24|10.1.20.3|TCP/80,443,9000|Camera to NVR (Reolink ports)|
|2|Allow|10.1.20.0/24|10.1.50.2|TCP/8088,8043, UDP/27001, TCP/29810-29814|Deco management by Omada|
|3|Allow|10.1.10.10|10.1.20.0/24|TCP/80,443,9000|Home Assistant camera integration|
|4|Allow|100.64.0.0/10|10.1.20.3|TCP/443|Remote NVR access via Tailscale (Reolink app)|
|5|Block|10.1.20.0/24|Any|Any|Block all other traffic|

- Notes:

  - Restricts cameras to local NVR and Omada controller for Deco management.
  - Home Assistant (10.1.10.10) can access cameras for integration.
  - Tailscale allows secure remote NVR access; block WAN access for security.

Interface: VLAN 30 (IoT, 10.1.30.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action Colonialism|Source|Destination|Protocol/Port|Description|
|1|Allow|10.1.30.0/24|10.1.10.10|Any|IoT to Home Assistant|
|2|Allow|10.1.30.0/24|Any|TCP/80,443|IoT internet access (e.g., firmware updates)|
|3|Block|10.1.30.0/24|Any|Any|Block all other traffic|

- Notes:

  - IoT devices only communicate with Home Assistant and the internet for updates.
  - No access to other VLANs or cross-home devices.

Interface: VLAN 40 (Guest, 10.1.40.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.1.40.0/24|Any|TCP/80,443|Guest internet access|
|2|Block|10.1.40.0/24|Any|Any|Block all other traffic|

- Notes:

  - Guests get internet access only, no LAN or cross-home access.

Interface: VLAN 50 (Management, 10.1.50.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.1.50.2|10.1.10.0/24, 10.1.20.0/24|TCP/8088,8043, UDP/27001, TCP/29810-29814|Omada to local APs/Decos|
|2|Allow|10.1.50.2|10.2.10.0/24, 10.2.20.0/24|TCP/8088,8043, UDP/27001, TCP/29810-29814|Omada to Primary Home APs/Decos|
|3|Allow|10.1.10.0/24|10.1.50.2|TCP/8088,8043|Local management of Omada|
|4|Block|10.1.50.0/24|Any|Any|Block all other traffic|

- Notes:

  - Omada controller manages APs/Decos locally and optionally cross-home.
  - Only Main LAN can access the controller's UI.

Primary Home Firewall Rules

Interface: WAN

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|Any|Any|UDP/41641|Allow Tailscale VPN traffic|
|2|Allow|Any|10.2.50.2|TCP/8088,8043|Omada Controller remote access (optional, restrict to VPN)|
|3|Allow|Any|10.2.10.10|TCP/8123|Home Assistant remote access (optional, prefer VPN)|
|4|Allow|Any|10.2.10.100|TCP/445,2049|NAS remote access (optional, prefer VPN)|
|5|Block|Any|Any|Any|Default deny|

- Notes:

  - Similar to Tennessee, with NAS access added (restrict to Tailscale for security).

Interface: VLAN 10 (Main LAN, 10.2.10.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.2.10.0/24|10.2.10.100|TCP/445,2049|Local NAS access (SMB/NFS)|
|2|Allow|10.2.10.0/24|10.1.10.10|TCP/8123|Access Tennessee Home Assistant|
|3|Allow|10.2.10.0/24|10.2.50.2|TCP/8088,8043, UDP/27001, TCP/29810-29814|Local Omada Controller|
|4|Allow|10.2.10.0/24|10.1.50.2|TCP/8088,8043, UDP/27001, TCP/29810-29814|Tennessee Omada Controller (if managing cross-home)|
|5|Allow|10.2.10.0/24|Any|TCP/80,443|Internet access|
|6|Allow|10.2.10.0/24|10.2.30.0/24|Any|Access IoT VLAN|
|7|Block|10.2.10.0/24|10.2.20.0/24|Any|Block access to Camera VLAN|
|8|Block|10.2.10.0/24|10.2.40.0/24|Any|Block access to Guest VLAN|

- Notes:

  - Adds local NAS access for laptops/desktops.
  - Symmetric to Tennessee for cross-home Home Assistant and Omada access.

Interface: VLAN 20 (Cameras, 10.2.20.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.2.20.0/24|10.2.20.3|TCP/80,443,9000|Camera to NVR|
|2|Allow|10.2.20.0/24|10.2.50.2|TCP/8088,8043, UDP/27001, TCP/29810-29814|Deco management by Omada|
|3|Allow|10.2.10.10|10.2.20.0/24|TCP/80,443,9000|Home Assistant camera integration|
|4|Allow|100.64.0.0/10|10.2.20.3|TCP/443|Remote NVR access via Tailscale|
|5|Block|10.2.20.0/24|Any|Any|Block all other traffic|

- Notes:

  - Identical to Tennessee, adjusted for Primary Home IPs.

Interface: VLAN 30 (IoT, 10.2.30.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.2.30.0/24|10.2.10.10|Any|IoT to Home Assistant|
|2|Allow|10.2.30.0/24|Any|TCP/80,443|IoT internet access|
|3|Block|10.2.30.0/24|Any|Any|Block all other traffic|

- Notes:

  - Same as Tennessee.

Interface: VLAN 40 (Guest, 10.2.40.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.2.40.0/24|Any|TCP/80,443|Guest internet access|
|2|Block|10.2.40.0/24|Any|Any|Block all other traffic|

- Notes:

  - Same as Tennessee.

Interface: VLAN 50 (Management, 10.2.50.0/24)

|||||||
|---|---|---|---|---|---|
|Order|Action|Source|Destination|Protocol/Port|Description|
|1|Allow|10.2.50.2|10.2.10.0/24, 10.2.20.0/24|TCP/8088,8043, UDP/27001, TCP/29810-29814|Omada to local APs/Decos|
|2|Allow|10.2.50.2|10.1.10.0/24, 10.1.20.0/24|TCP/8088,8043, UDP/27001, TCP/29810-29814|Omada to Tennessee APs/Decos|
|3|Allow|10.2.10.0/24|10.2.50.2|TCP/8088,8043|Local management of Omada|
|4|Block|10.2.50.0/24|Any|Any|Block all other traffic|

- Notes:

  - Symmetric to Tennessee, with cross-home Omada management optional.

Tailscale ACLs (Complementary)

To reinforce OPNSense rules, configure Tailscale ACLs in the admin console (https://login.tailscale.com/admin/acls):

json

```json
{
  "acls": [
    // NAS access
    {"action": "accept", "src": ["10.1.10.0/24", "10.2.10.0/24"], "dst": ["10.2.10.100:445", "10.2.10.100:2049"]},
    // Home Assistant access
    {"action": "accept", "src": ["10.1.10.0/24", "10.2.10.0/24"], "dst": ["10.1.10.10:8123", "10.2.10.10:8123"]},
    // Omada controller (Tennessee managing both homes)
    {"action": "accept", "src": ["10.1.50.2"], "dst": ["10.1.10.0/24:8088,8043,27001,29810-29814", "10.1.20.0/24:8088,8043,27001,29810-29814", "10.2.10.0/24:8088,8043,27001,29810-29814", "10.2.20.0/24:8088,8043,27001,29810-29814"]},
    // NVR remote access
    {"action": "accept", "src": ["100.64.0.0/10"], "dst": ["10.1.20.3:443", "10.2.20.3:443"]}
  ]
}
```

- Notes:

  - Restricts Tailscale traffic to specific services.
  - Adjust if using Primary Home's Omada controller or dual controllers.

Implementation Steps

1. Add Rules in OPNSense:

   - Go toFirewall > Rules > \[Interface\]in the OPNSense GUI.
   - Create each rule, specifying source, destination, protocol/port, and description.
   - Set "Log" for initial testing, then disable for high-traffic rules (e.g., internet access).
2. Test Rules:

   - From Tennessee VLAN 10 (e.g., a laptop), access the NAS (10.2.10.100) via SMB (smb://100.64.1.4).
   - Verify Home Assistant (10.1.10.10, 10.2.10.10) is accessible cross-home.
   - Check Omada controller (10.1.50.2) manages APs/Decos in both homes.
   - Confirm cameras (VLAN 20) are isolated except for NVR and Home Assistant.
   - Test guest VLAN (10.1.40.0/24) has internet but no LAN access.
3. Monitor Logs:

   - CheckFirewall > Log Files > Live Viewfor blocked/allowed traffic.
   - Adjust rules if legitimate traffic is blocked.
4. Update Tailscale ACLs:

   - Edit ACLs in the Tailscale admin console to match the above JSON.
   - Test withtailscale ping 10.2.10.100from Tennessee.

Considerations

- NAS Security:

  - Prefer Tailscale for NAS access (100.64.1.4) over WAN to avoid exposing ports 445/2049.
  - Use strong SMB credentials and consider IP whitelisting in TrueNAS.
- Omada Management:

  - The rules assume one Omada controller (e.g., Tennessee's 10.1.50.2) manages both homes. If using dual controllers, adjust VLAN 50 rules.
- Camera Isolation:

  - VLAN 20 is locked down to prevent unauthorized access. Add rules for cross-home NVR access if needed.
- Starlink:

  - Tailscale's UDP 41641 rule ensures connectivity despite Starlink's CGNAT.
- Future NAS:

  - When adding Tennessee's NAS (10.1.10.100), mirror Primary Home's NAS rules (e.g., allow 10.2.10.0/24 to 10.1.10.100:445,2049).
- Performance:

  - Rules are lightweight, but enable hardware offloading in OPNSense (System > Settings > Miscellaneous) for 10Gbps throughput.
- Logging:

  - Disable logging for HTTP/HTTPS rules to reduce SSD writes on high-traffic networks.

Testing and Validation

- Cross-Home Access:

  - Tennessee laptop to Primary Home NAS:smb://10.2.10.100orsmb://100.64.1.4.
  - Primary Home desktop to Tennessee Home Assistant:https://10.1.10.10:8123.
- VLAN Isolation:

  - Guest device (10.1.40.x) should fail to ping 10.1.10.10.
  - Camera (10.1.20.x) should only reach NVR (10.1.20.3).
- Tailscale:

  - Verify subnet routes:tailscale statusshows 10.1.x.x and 10.2.x.x.
  - Test failover: Disconnect fiber, confirm Starlink maintains Tailscale connectivity.

## Proxmox Firewall Deployment with Ansible

This repository contains Ansible playbooks for automating the deployment of Proxmox-based firewalls for multiple homes.

### Prerequisites

- Ansible 2.9+ installed on your control machine
- SSH access to Proxmox hosts
- Basic understanding of Proxmox, OPNsense, and networking

### Quick Start

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/proxmox-firewall.git
   cd proxmox-firewall
   ```

2. Update the inventory file with your Proxmox hosts:

   ```bash
   vim ansible/inventory/hosts.yml
   ```

3. Create a file with SSH public keys for root access:

   ```bash
   vim ssh_authorized_keys
   # Add one public key per line
   ```

4. Run the master playbook to deploy everything:

   ```bash
   ansible-playbook ansible/master_playbook.yml
   ```

### Deployment Process

The deployment consists of the following stages:

1. Configure Proxmox repositories (no subscription)
2. Perform initial Proxmox system setup
3. Configure SSH keys and security
4. Set up Terraform API access
5. Configure network bridges and VLANs
6. Create VM templates
7. Deploy VMs with Terraform

### Playbooks

#### Master Playbook

The `master_playbook.yml` file orchestrates the entire deployment process. Run it with:

```bash
ansible-playbook ansible/master_playbook.yml
```

#### Individual Playbooks

You can run individual playbooks for specific tasks:

| Playbook | Description | Command |
|----------|-------------|---------|
| `00_configure_repos.yml` | Configure Proxmox repositories | `ansible-playbook ansible/playbooks/00_configure_repos.yml` |
| `01_initial_setup.yml` | Initial Proxmox configuration | `ansible-playbook ansible/playbooks/01_initial_setup.yml` |
| `02a_update_ssh_keys.yml` | Configure SSH authorized keys | `ansible-playbook ansible/playbooks/02a_update_ssh_keys.yml` |
| `02b_disable_root_password.yml` | Disable root password login | `ansible-playbook ansible/playbooks/02b_disable_root_password.yml` |
| `02_terraform_api.yml` | Setup Terraform API access | `ansible-playbook ansible/playbooks/02_terraform_api.yml` |
| `03_network_setup.yml` | Configure network bridges | `ansible-playbook ansible/playbooks/03_network_setup.yml` |
| `04_vm_templates.yml` | Create VM templates | `ansible-playbook ansible/playbooks/04_vm_templates.yml` |
| `05_deploy_vms.yml` | Deploy VMs with Terraform | `ansible-playbook ansible/playbooks/05_deploy_vms.yml` |
| `06_opnsense_setup.yml` | Configure OPNsense firewalls | `ansible-playbook ansible/playbooks/06_opnsense_setup.yml` |
| `07a_opnsense_suricata.yml` | Configure Suricata IDS/IPS | `ansible-playbook ansible/playbooks/07a_opnsense_suricata.yml` |
| `07b_zeek_setup.yml` | Configure Zeek monitoring | `ansible-playbook ansible/playbooks/07b_zeek_setup.yml` |

#### Using Tags

The master playbook uses tags for selective execution:

```bash
# Run only network setup
ansible-playbook ansible/master_playbook.yml --tags network

# Skip VM deployment
ansible-playbook ansible/master_playbook.yml --skip-tags deploy

# Run only security-related playbooks
ansible-playbook ansible/master_playbook.yml --tags security
```

### SSH Key Setup

The playbooks use a centralized approach to SSH key management:

1. **Environment Configuration**:
   - `ANSIBLE_SSH_PRIVATE_KEY_FILE` in `.env` defines the private key path
   - This is imported into Ansible as `ansible_ssh_private_key_file` in `all.yml`

2. **Proxmox Host Keys**:
   - Generated in `01_initial_setup.yml` for each Proxmox host
   - Used as bastion keys for accessing VMs
   - Automatically updated in `.env` as `TF_VAR_ssh_public_key`

3. **Repository Keys File**:
   - Create `ssh_authorized_keys` in the repository root
   - One public key per line for team access
   - Preferred over individual keys for multi-user management

When Ansible runs, these key relationships are maintained:

- Your key → Ansible → Proxmox hosts
- Proxmox keys → Terraform → VMs

**Important:** Before running `02b_disable_root_password.
yml` to disable password authentication, ensure your SSH 
keys are properly set up to prevent lockouts.

### Network Configuration

The deployment configures the following network bridges:

- `vmbr0` (LAN): 10G SFP+ port with VLANs 10, 30, 40, 50
- `vmbr1` (WAN - Fiber): 2.5G port
- `vmbr2` (Cameras): 10G SFP+ port with VLAN 20
- `vmbr3` (WAN - Starlink): 2.5G port for failover

IP schemes:

- Tennessee: 10.1.x.x/16
- Primary Home: 10.2.x.x/16

### Deployed VMs

The deployment creates the following VMs:

1. **OPNsense Firewall**
   - Multiple network interfaces for LAN, Camera, and dual WANs
   - Configured for firewall and routing
   - Implements VLANs and firewall rules as defined in the plan
   - Uses Tailscale for cross-site connectivity

2. **Omada Controller**
   - Management for TP-Link access points
   - IP: 10.x.50.2 (VLAN 50)

3. **Tailscale VM**
   - Linux-based WireGuard VPN for cross-site communication
   - IP: 10.x.50.3 (VLAN 50)

### OPNsense Configuration

The OPNsense firewalls are configured with Ansible using the ansibleguy.opnsense collection. The configuration includes:

#### Network Interfaces and VLANs

Each OPNsense firewall is configured with:

- LAN (10G SFP+) - VLAN 10 (Main), 30 (IoT), 40 (Guest), 50 (Management)
- Camera (10G SFP+) - VLAN 20 (Cameras)
- WAN - Primary Fiber (2.5G) and Starlink failover (2.5G)

#### Firewall Rules

Comprehensive firewall rules are applied to:
- Allow cross-site access for specific services (NAS, Home Assistant, Omada)
- Segregate VLANs for security (guest, IoT, cameras)
- Permit necessary internet access while blocking unwanted traffic
- Configure tailscale for secure site-to-site VPN

#### DHCP and Static Mappings

Each network interface has its own DHCP server with appropriate IP ranges and static mappings for:
- Home Assistant (10.x.10.10)
- Omada Controller (10.x.50.2)
- NAS (10.2.10.100 - Primary Home only)
- Camera equipment (Reolink Hub, NVR)

#### Tailscale Integration

Both firewalls are configured as Tailscale exit nodes advertising their respective subnets:
- Tennessee: 10.1.0.0/16
- Primary Home: 10.2.0.0/16

This allows secure communication between the sites via the Tailscale mesh network.

### Security Notes

- SSH keys are used for authentication
- Root password authentication can be disabled
- API tokens are securely stored in the credentials directory
- Tailscale provides secure communication between sites

### Credentials

All credentials generated during deployment are stored in the `credentials/` directory:

- Proxmox API tokens
- SSH public keys
- Other secrets

The credentials are also incorporated into the `.env` file which is used by Terraform.

### Security Monitoring

The deployment includes comprehensive security monitoring capabilities through Suricata and Zeek:

#### Suricata IDS/IPS

Suricata is deployed directly on the OPNsense firewalls:

- **Detection Capabilities**:
  - Real-time traffic monitoring on both WAN interfaces
  - Emerging Threats ruleset for detecting known threats
  - Custom rules for home network protection

- **Key Features**:
  - Intrusion Detection System (IDS) and Prevention System (IPS)
  - Protocol anomaly detection
  - Automatic rule updates (every 12 hours)
  - Integrated with OPNsense reporting

- **Management**:
  - Accessible through the OPNsense web interface at https://firewall-ip/ui/ids
  - Alert logs viewable in the OPNsense system logs

#### Zeek Network Security Monitor

Zeek provides deep network analysis on a dedicated VM:

- **Deployment**:
  - Separate lightweight Ubuntu VM (2 CPU cores, 4GB RAM)
  - Passive monitors on both WAN interfaces
  - Configured for minimal performance impact

- **Key Features**:
  - Protocol-aware traffic analysis
  - Connection tracking and logging
  - SSL certificate validation
  - File extraction and hash calculation
  - JA3 fingerprinting for TLS connections
  - Community ID for cross-platform correlation

- **Management**:
  - Web dashboard accessible at http://zeek-ip:8888
  - JSON-formatted logs for easy analysis
  - Alert forwarding to OPNsense syslog
  - Log rotation with 7-day retention

#### Integration

The two systems complement each other:

- Suricata provides real-time protection with known signatures
- Zeek provides deeper analysis for advanced threat hunting
- Cross-correlation of alerts via syslog integration
- Firewall rules automatically permit access to management interfaces
