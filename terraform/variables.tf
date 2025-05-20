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
  description = "Network prefix (10.1 for Tennessee, 10.2 for Primary Home)"
  type        = string
  default     = "10.1"
}
