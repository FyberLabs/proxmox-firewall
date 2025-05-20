terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://${var.proxmox_host}:8006/api2/json"
  pm_api_token_id     = "tfuser@pve!terraform"
  pm_api_token_secret = var.proxmox_api_secret
  pm_tls_insecure     = true
}
