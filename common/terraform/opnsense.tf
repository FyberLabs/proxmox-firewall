resource "proxmox_vm_qemu" "opnsense" {
  count       = var.vm_templates["opnsense"].enabled ? 1 : 0
  name        = "opnsense-firewall"
  desc        = "OPNsense firewall with multiple interfaces"
  target_node = var.target_node
  clone       = "template-freebsd-opnsense"
  os_type     = "other"

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }
  memory   = 6144
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  disk {
    slot    = "virtio0"
    size    = "64G"
    type    = "disk"
    storage = "local-lvm"
  }

  # LAN (vmbr0)
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # WAN - Fiber (vmbr1)
  network {
    id     = 1
    model  = "virtio"
    bridge = "vmbr1"
  }

  # Cameras (vmbr2)
  network {
    id     = 2
    model  = "virtio"
    bridge = "vmbr2"
  }

  # WAN - Starlink (vmbr3)
  network {
    id     = 3
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
  # Note: start_on_deploy is handled by onboot setting
}
