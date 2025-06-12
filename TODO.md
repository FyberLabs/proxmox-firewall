# TODO

## In Progress

- IP for proxmox needs to be dhcp to initialize then static in 10. net (implemented, needs testing)

## Missing Scripts/Documentation Issues

### Missing Scripts Referenced in Documentation

✅ **RESOLVED**: `fetch_credentials.sh` - Moved from `deployment/scripts/` to `common/scripts/` and documentation updated
  - Script retrieves API tokens and keys from deployed systems
  - Stores them securely in credentials directory
  - Updates .env file with retrieved values
  - Now accessible from both deployment and local operations

### Documentation References to Review
- **API.md** contains placeholder examples that may need real implementation details
- **TROUBLESHOOTING.md** references specific commands that should be validated
- **FAQ.md** contains answers that should be verified against actual implementation

### Scripts That Exist and Work

✅ `./deployment/scripts/prerequisites.sh` - Exists and functional
✅ `./deployment/scripts/download_latest_images.sh` - Exists and functional  
✅ `./deployment/scripts/create_site_config.sh` - Exists and functional
✅ `./common/scripts/add_device.sh` - Exists and functional
✅ `./common/scripts/fetch_credentials.sh` - Moved from deployment/scripts and functional
✅ `./validate-config.sh` - Exists at root level
✅ `./scripts/setup-fork.sh` - Newly created and functional
✅ `./deployment/scripts/render_template.py` - Exists and used by add_device.sh
✅ `env.example` - Exists at root level
✅ Device templates in `config/devices_templates/` - Extensive collection exists

## Fixes

- Insure vlan_config is in site config yml
- answer file jinja fix
- what is device config jinja???
- use hostname for site config in local ansible (✓ implemented)
- clean up the masters mess (✓ implemented)
- cron job loader for local (✓ implemented)

## Documentation

- Update README.md to mention single/multifirewall and remove specific devices, hubs, nvr, etc. as we have those as optional devices now.
- Create some sample mermaid network diagrams showing VLANs and example devices

## Features

- Zabbix SNMP VM
- Prometheus and snmp_exporter
- Grafana
- bsnmp for OPNSense?

## Automation

- Develop the update scripts for the non-package repo VM software.
- Setup self-running/hosted ansible in proxmox for the various maintenance scripts - reorg ansible to install/(on proxmox) post-install?
- clean up answer file templates [reference](https://pve.proxmox.com/wiki/Automated_Installation)
- apply_hardware_config.yml needs cleaned up and some sort of loader in proxmox
- add more missing implemented components to site_template.yml and use it in create_site_config.sh
- document new process for making ISOs and put their output somewhere better.
- review hardware validation sanity

## Multi-Site Improvements

- Add support for different hardware configurations per site
- Support different network topologies per site
- Create global network sharing ansible examples for connecting networks by tailscale (terraform), headscale(terraform), and netbird(terraform) depending on site and a yet to be specified global network config.
- Support self-hosted VPN control plane/DNS - Specify DMZ, DMZ VM, cloud VM for headscale or self hosted netbird.

## Validation Tests

### Security Validation

- Test monitoring setup
  - Verify Zeek logging
  - Check Suricata rules
  - Validate log rotation
  - Test alert configuration
