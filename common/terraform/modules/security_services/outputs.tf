output "security_services_ip" {
  value       = var.enabled ? proxmox_vm_qemu.security_services[0].default_ipv4_address : null
  description = "IP address of the security services VM"
}

output "security_services_name" {
  value       = var.enabled ? proxmox_vm_qemu.security_services[0].name : null
  description = "Name of the security services VM"
}

output "security_services_status" {
  value       = var.enabled ? proxmox_vm_qemu.security_services[0].startup : null
  description = "Startup configuration of the security services VM"
}
