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
