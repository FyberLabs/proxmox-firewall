# README

## Layout

```text
ansible/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml
│       ├── tennessee.yml
│       └── primary_home.yml
├── playbooks/
│   ├── 01_initial_setup.yml
│   ├── 02_terraform_api.yml
│   ├── 03_network_setup.yml
│   ├── 04_vm_templates.yml
│   └── 05_deploy_vms.yml
├── roles/
│   ├── proxmox_base/
│   ├── proxmox_network/
│   ├── proxmox_api/
│   ├── vm_templates/
│   ├── deploy_opnsense/
│   ├── deploy_omada/
│   └── deploy_tailscale/
└── fetch_credentials.sh
```
