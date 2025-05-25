output "headscale_server_ip" {
  value       = var.enabled ? proxmox_vm_qemu.headscale_server[0].default_ipv4_address : null
  description = "IP address of the Headscale server VM"
}

output "headscale_server_name" {
  value       = var.enabled ? proxmox_vm_qemu.headscale_server[0].name : null
  description = "Name of the Headscale server VM"
}

output "headscale_server_status" {
  value       = var.enabled ? proxmox_vm_qemu.headscale_server[0].status : null
  description = "Status of the Headscale server VM"
}
