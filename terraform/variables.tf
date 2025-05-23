variable "proxmox_host" {
  description = "Proxmox host IP or FQDN"
  type        = string
}

variable "proxmox_api_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (from Proxmox root key)"
  type        = string
}

variable "ssh_private_key_file" {
  description = "Path to SSH private key file for provisioning"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key"
  type        = string
  sensitive   = true
}

variable "timezone" {
  description = "Timezone for VMs"
  type        = string
  default     = "UTC"
}

variable "target_node" {
  description = "Proxmox node to deploy VMs"
  type        = string
  default     = "pve"
}

variable "network_prefix" {
  description = "Network prefix (e.g., 10.1 for site1, 10.2 for site2)"
  type        = string
}

variable "site_name" {
  description = "Short name of the site (e.g., primary, secondary)"
  type        = string
}

variable "site_display_name" {
  description = "Human-readable name of the site (e.g., Primary Home)"
  type        = string
}

variable "domain" {
  description = "Local domain name for the site (e.g., primary.local)"
  type        = string
}

variable "vm_templates" {
  description = "Configuration for VM template deployment"
  type = map(object({
    enabled = bool
    start_on_deploy = bool
  }))
  default = {
    opnsense = {
      enabled = true
      start_on_deploy = true
    }
    omada = {
      enabled = true
      start_on_deploy = true
    }
    zeek = {
      enabled = true
      start_on_deploy = false
    }
    tailscale = {
      enabled = false
      start_on_deploy = true
    }
  }
}
