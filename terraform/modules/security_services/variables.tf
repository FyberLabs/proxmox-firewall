variable "enabled" {
  description = "Whether to create the security services VM"
  type        = bool
  default     = true
}

variable "site_name" {
  description = "Short name of the site (e.g., primary, secondary)"
  type        = string
}

variable "site_display_name" {
  description = "Human-readable name of the site"
  type        = string
}

variable "network_prefix" {
  description = "Network prefix (e.g., 10.1 for site1, 10.2 for site2)"
  type        = string
}

variable "domain" {
  description = "Local domain name for the site"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to deploy the VM"
  type        = string
  default     = "pve"
}

variable "ubuntu_template_id" {
  description = "ID of the Ubuntu template to clone"
  type        = string
}

variable "security_password" {
  description = "Password for the security services VM"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_private_key_file" {
  description = "Path to SSH private key file for provisioning"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "proxmox_storage" {
  description = "Proxmox storage pool for VM disk"
  type        = string
  default     = "local-lvm"
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
