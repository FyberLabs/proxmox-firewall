resource "proxmox_vm_qemu" "opnsense" {
  count       = var.vm_templates["opnsense"].enabled ? 1 : 0
  name        = "opnsense-firewall"
  desc        = "OPNsense firewall with multiple interfaces"
  target_node = var.target_node
  clone       = "template-freebsd-opnsense"
  os_type     = "other"

  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 6144
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  disk {
    slot    = 0
    size    = "64G"
    type    = "virtio"
    storage = "local-lvm"
  }

  # LAN (vmbr0)
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # WAN - Fiber (vmbr1)
  network {
    model  = "virtio"
    bridge = "vmbr1"
  }

  # Cameras (vmbr2)
  network {
    model  = "virtio"
    bridge = "vmbr2"
  }

  # WAN - Starlink (vmbr3)
  network {
    model  = "virtio"
    bridge = "vmbr3"
  }

  # Enable VirtIO SCSI controller
  serial {
    id = 0
    type = "socket"
  }

  agent = 1

  # Boot from virtio0 disk
  boot = "order=virtio0;net0"

  # VM settings
  onboot = true
  oncreate = var.vm_templates["opnsense"].start_on_deploy
}
