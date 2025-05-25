terraform {
  required_version = ">= 1.12.1"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc9"
    }
  }

  # Backend configuration - will be configured dynamically
  # This is just a placeholder - the actual backend will be set
  # via terraform init -backend-config for each site
  backend "local" {
    # Path will be set to terraform/states/${site_name}/terraform.tfstate
  }
}

provider "proxmox" {
  pm_api_url      = "https://${var.proxmox_host}:8006/api2/json"
  pm_api_token_id = "terraform@pve!terraform-token"
  pm_api_token_secret = var.proxmox_api_secret
  pm_tls_insecure = true
}

# Local variables for VM template configuration
locals {
  # Get VM template configuration from tfvars
  vm_templates = var.vm_templates

  # Create a map of enabled templates
  enabled_templates = {
    for name, config in local.vm_templates : name => config
    if config.enabled
  }
}

# The VM resources are defined in their respective .tf files:
# - opnsense.tf
# - omada.tf
# - zeek.tf
# - tailscale.tf (to be created)

# We use count to control whether each VM is created based on the enabled_templates map
# The start_on_deploy parameter is handled in each VM's configuration

module "tailscale_network" {
  source = "./modules/tailscale_network"

  enabled            = var.vm_templates["tailscale"].enabled
  site_name          = var.site_name
  site_display_name  = var.site_display_name
  network_prefix     = var.network_prefix
  domain            = var.domain
  target_node       = var.target_node
  ubuntu_template_id = var.ubuntu_template_id
  tailscale_password = var.tailscale_password
  tailscale_auth_key = var.tailscale_auth_key
  ssh_public_key     = var.ssh_public_key
  ssh_private_key_file = var.ssh_private_key_file
  proxmox_storage    = var.proxmox_storage
}

module "netbird_network" {
  source = "./modules/netbird_network"

  enabled            = var.vm_templates["netbird"].enabled
  site_name          = var.site_name
  site_display_name  = var.site_display_name
  network_prefix     = var.network_prefix
  domain            = var.domain
  target_node       = var.target_node
  ubuntu_template_id = var.ubuntu_template_id
  netbird_password   = var.netbird_password
  netbird_setup_key  = var.netbird_setup_key
  ssh_public_key     = var.ssh_public_key
  ssh_private_key_file = var.ssh_private_key_file
  proxmox_storage    = var.proxmox_storage
}

module "headscale_network" {
  source = "./modules/headscale_network"

  enabled            = var.vm_templates["headscale"].enabled
  site_name          = var.site_name
  site_display_name  = var.site_display_name
  network_prefix     = var.network_prefix
  domain            = var.domain
  target_node       = var.target_node
  ubuntu_template_id = var.ubuntu_template_id
  headscale_password = var.headscale_password
  ssh_public_key     = var.ssh_public_key
  ssh_private_key_file = var.ssh_private_key_file
  proxmox_storage    = var.proxmox_storage
}

module "security_services" {
  source = "./modules/security_services"

  enabled            = var.vm_templates["security_services"].enabled
  site_name          = var.site_name
  site_display_name  = var.site_display_name
  network_prefix     = var.network_prefix
  domain            = var.domain
  target_node       = var.target_node
  ubuntu_template_id = var.ubuntu_template_id
  security_password  = var.security_password
  pangolin_db_password = var.pangolin_db_password
  pangolin_secret_key = var.pangolin_secret_key
  crowdsec_api_key    = var.crowdsec_api_key
  crowdsec_db_password = var.crowdsec_db_password
  ssh_public_key     = var.ssh_public_key
  ssh_private_key_file = var.ssh_private_key_file
  proxmox_storage    = var.proxmox_storage
}
