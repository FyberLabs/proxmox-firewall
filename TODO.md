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

- Generate/include tfvars from site config and generate a template for it as part of ansible before terraform
- Setup the tfstate backend in ansible before terraform
- Make VM template deployment selectable in site config, ie. all templates deploy to proxmox, but not all are started as VMs

## Ansible Refactor

- Include in site generation missing ansible vars from env too
- Remove environment use then if possible
- Remove Tennessee and Primary Home references

## Refactor Firewall

- Remove Tennessee and Primary Home references
- Give example network device firewall rules instead of hard coding
- Cameras and IoT devices on their networks should cloud connect but not wide open WAN access.

## Documentation

- Update README.md to mention single/multifirewall and remove specific references to Tennesee home, Primary Home, and specific devices, hubs, nvr, etc. as we have those as optional devices now.
- Create a sample network diagram showing VLANs and example devices

## Networking

- We should provide dhcp for all local VLANs
- Test network transition from initial DHCP IPs to Management VLAN IPs
- Test OPNsense Tailscale integration across sites

## Security & Monitoring

- tailscale terraform to connect networks by firewall
- Add support for netbird as an alternative to tailscale
- Support headscale self hosting
- Also pangolin and crowdsec for SSO WAN access
- Validate image downloads cert/signature

## Automation

- Make a requirements script for python and a prereq script that runs it and installs ubuntu packages needed
- Make a script to find latest sources and hashes and populate a versions file that is sourced by ansible for templates, etc.
- Automatically get latest Ubuntu base for VMs
- Automatically get latest Omada
- Automatically get latest zeek, pangolin, headscale, etc.
- Setup ansible for log/metric offloading/rotation/trim, system recovery, removing VM templates, etc.
- Verify backup configuration works with both NFS and CIFS

## Multi-Site Improvements

- Create site transition script to migrate from hardcoded to dynamic config
- Update README with multi-site deployment instructions
- Create test suite for multi-site deployment
- Add support for different hardware configurations per site
- Support different network topologies per site
- Create global network sharing ansible for connecting networks by tailscale (terraform), headscale(terraform), and netbird(terraform) depending on site and a yet to be specified global network config.
