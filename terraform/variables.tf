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
    netbird = {
      enabled = false
      start_on_deploy = true
    }
    headscale = {
      enabled = false
      start_on_deploy = true
    }
    security_services = {
      enabled = false
      start_on_deploy = true
    }
  }
}

variable "ubuntu_template_id" {
  description = "ID of the Ubuntu template to clone"
  type        = string
  default     = "9001"
}

variable "ubuntu_version" {
  description = "Version of Ubuntu to use"
  type        = string
}

variable "ubuntu_image_path" {
  description = "Path to the Ubuntu template image"
  type        = string
}

variable "opnsense_version" {
  description = "Version of OPNsense to use"
  type        = string
}

variable "opnsense_image_path" {
  description = "Path to the OPNsense image"
  type        = string
}

variable "proxmox_storage" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "netbird_setup_key" {
  description = "Netbird setup key for network enrollment"
  type        = string
  sensitive   = true
}

variable "netbird_password" {
  description = "Password for the Netbird VM"
  type        = string
  sensitive   = true
}

variable "headscale_password" {
  description = "Password for the Headscale VM"
  type        = string
  sensitive   = true
}

variable "security_password" {
  description = "Password for the security services VM"
  type        = string
  sensitive   = true
}

variable "pangolin_db_password" {
  description = "Password for the Pangolin database"
  type        = string
  sensitive   = true
}

variable "pangolin_secret_key" {
  description = "Secret key for Pangolin SSO"
  type        = string
  sensitive   = true
}

variable "crowdsec_api_key" {
  description = "API key for Crowdsec"
  type        = string
  sensitive   = true
}

variable "crowdsec_db_password" {
  description = "Password for the Crowdsec database"
  type        = string
  sensitive   = true
}
