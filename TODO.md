# TODO

## Completed

- ✅ Create a single firewall layout that scales
- ✅ Support dynamic multi-site configuration
- ✅ Create configuration script for multiple sites
- ✅ Terraform per-site state files
- ✅ Make script to add specific important host devices into the network from yaml files
- ✅ Create example yaml devices: Phone, Laptop, Desktop PC, Game console, TV, NVR, Reolink Hub, Homeassistant, TrueNAS, Kubernetes Cluster
- ✅ Dynamic firewall rules based on device types and VLAN configuration
- ✅ Create Jinja2-based device template system for flexible device configuration
- ✅ Integrate template system with the device configuration script
- ✅ Unify device documentation into a single comprehensive guide

## In Progress

- IP for proxmox needs to be dhcp to initialize then static in 10. net (implemented, needs testing)

## Refactor terraform for site config control

- ✅ Generate/include tfvars from site config and generate a template for it as part of ansible before actual terraform runs
- ✅ Setup the tfstate backend in ansible before terraform
- ✅ Make VM template deployment selectable in site config, ie. all templates deploy to proxmox, but not all are started as VMs

## Ansible Refactor

- ✅ Include in site generation missing ansible vars from env too
- ✅ Remove environment use as much as possible
- ✅ Reload env as needed when updated in README.md steps and master playbook
- ✅ Remove Tennessee and Primary Home references
- ✅ Remove hardcoded device references in IPs, MACs, etc.

## Refactor Firewall

- ✅ Remove Tennessee and Primary Home references
- ✅ Remove specific hardcoded devices
- ✅ Give example network device firewall rules instead of hard coding
- ✅ Cameras and IoT devices on their networks should cloud connect but not wide open WAN access.
- ✅ Homeassistant and iot hubs should see all IoT VLAN devices, but the devices shouldn't see each other, only their cloud access.

## Documentation

- Update README.md to mention single/multifirewall and remove specific references to Tennesee home, Primary Home, and specific devices, hubs, nvr, etc. as we have those as optional devices now.
- Create some sample mermaid network diagrams showing VLANs and example devices

## Networking

- ✅ Provide DHCP for all local VLANs
- ✅ Test network transition from initial DHCP IPs to Management VLAN IPs
- ✅ Test OPNsense Tailscale integration across sites

## Security & Monitoring

- ✅ tailscale terraform to connect networks by firewall
- ✅ Add support for netbird as an alternative to tailscale
- ✅ Support headscale self hosting not just tailscale control plane
- Also VM for pangolin and crowdsec for SSO WAN access
- ✅ Validate image downloads cert/signature
- Does crowdsec docker actually work OK in proxmox?
- (https://www.reddit.com/r/selfhosted/comments/1jp5l21/security_measures_when_using_pangolin/)

## Automation

- ✅ Make a requirements script for python and a prereq script that runs it and installs ubuntu packages needed
- ✅ Make a script to find latest sources and hashes and populate a versions file that is sourced by ansible for templates, etc.
- ✅ Automatically get latest Ubuntu base for VMs
- ✅ Automatically get latest Omada
- ✅ Automatically get latest zeek, pangolin, headscale, etc.
- ✅  Setup ansible for log/metric offloading/rotation/trim, system recovery, removing VM templates, etc.
- ✅  Script to update/redeploy/reconfigure new VM versions
- ✅ Verify backup configuration works with both NFS and CIFS
- ✅ Add CEPH blob backup support?
- ✅ VM_software needs reworked as packages should be updating and only install script software needs help updating.  Also version updating notifications.
- Develop the update scripts for the non-package repo VM software.
- Setup self-running/hosted ansible in proxmox for the various maintenance scritps?

## Multi-Site Improvements

- ✅ Update README with multi-site deployment instructions
- ✅ Create test suite for multi-site deployment
- Add support for different hardware configurations per site
- Support different network topologies per site
- Create global network sharing ansible examples for connecting networks by tailscale (terraform), headscale(terraform), and netbird(terraform) depending on site and a yet to be specified global network config.
- Support self-hosted VPN control plane/DNS - Specify DMZ, DMZ VM, cloud VM for headscale or self hosted netbird.

## Validation Tests

### Firewall State Validation
- ✅ Test OPNsense service status and configuration
  - ✅ Verify all required packages are installed (os-tailscale, os-theme-vicuna, os-wireguard)
  - ✅ Check firewall rules are properly applied
  - ✅ Validate NAT rules for WAN failover
  - ✅ Verify DNS resolver configuration
  - ✅ Check DHCP server status and leases
  - ✅ Validate VLAN configuration and tagging

### VM State Validation
- ✅ Test Proxmox VM states
  - ✅ Verify all VMs are running with correct resources
  - ✅ Check cloud-init configuration
  - ✅ Validate network interface assignments
  - ✅ Test VM template versions and updates
  - ✅ Verify backup configuration

### Network Connectivity Tests
- ✅ Test from inside OPNsense
  - ✅ Verify WAN connectivity (both primary and failover)
  - ✅ Test VLAN routing and isolation
  - ✅ Validate DNS resolution
  - ✅ Check DHCP server functionality
  - ✅ Test firewall rule effectiveness
  - ✅ Verify Tailscale subnet routing

- ✅ Test from localhost to services
  - ✅ Verify SSH access to all VMs
  - ✅ Test web interface access (OPNsense, Omada)
  - ✅ Validate service ports (Home Assistant, NAS, etc.)
  - ✅ Check Tailscale connectivity
  - ✅ Test cross-site routing

### Security Validation
- ✅ Verify firewall rules
  - ✅ Test VLAN isolation
  - ✅ Validate service access restrictions
  - ✅ Check WAN access controls
  - ✅ Test failover security
  - ✅ Verify Tailscale ACLs

- Test monitoring setup
  - Verify Zeek logging
  - Check Suricata rules
  - Validate log rotation
  - Test alert configuration
