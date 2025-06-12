# TODO

## In Progress

- IP for proxmox needs to be dhcp to initialize then static in 10. net (implemented, needs testing)

## Fixes

- Insure vlan_config is in site config yml
- answer file jinja fix
- what is device config jinja???

## Documentation

- Update README.md to mention single/multifirewall and remove specific devices, hubs, nvr, etc. as we have those as optional devices now.
- Create some sample mermaid network diagrams showing VLANs and example devices
- Validate API.md placeholder examples against real implementation details
- Validate TROUBLESHOOTING.md referenced commands
- Verify FAQ.md answers against actual implementation

## Features

- Zabbix SNMP VM
- Prometheus and snmp_exporter
- Grafana
- bsnmp for OPNSense?

## Automation

- Develop the update scripts for the non-package repo VM software.
- Setup self-running/hosted ansible in proxmox for the various maintenance scripts - reorg ansible to install/(on proxmox) post-install?
- have firewalls pull local deployment repo to update their ansible/scripts
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
