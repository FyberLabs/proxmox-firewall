output "netbird_router_ip" {
  value       = var.enabled ? proxmox_vm_qemu.netbird_router[0].default_ipv4_address : null
  description = "IP address of the Netbird router VM"
}

output "netbird_router_name" {
  value       = var.enabled ? proxmox_vm_qemu.netbird_router[0].name : null
  description = "Name of the Netbird router VM"
}

output "netbird_router_status" {
  value       = var.enabled ? proxmox_vm_qemu.netbird_router[0].startup : null
  description = "Startup configuration of the Netbird router VM"
}
