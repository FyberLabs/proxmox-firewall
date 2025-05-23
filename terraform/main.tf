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
