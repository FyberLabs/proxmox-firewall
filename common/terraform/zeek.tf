# Zeek Network Security Monitor VM

resource "proxmox_vm_qemu" "zeek" {
  count       = var.vm_templates["zeek"].enabled ? 1 : 0
  name        = "zeek-${var.site_name}"
  desc        = "Zeek Network Security Monitor for ${var.site_display_name}"
  target_node = var.target_node
  clone       = var.ubuntu_template_id
  os_type     = "cloud-init"

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }
  memory      = 4096
  agent       = 1

  # Cloud-init settings
  ipconfig0   = "ip=${var.network_prefix}.50.4/24,gw=${var.network_prefix}.50.254"
  nameserver  = "${var.network_prefix}.10.1"
  searchdomain = "${var.domain}"

  # Network interfaces:
  # First interface: Management (on VLAN50)
  network {
    id       = 0
    model    = "virtio"
    bridge   = "vmbr0"
    tag      = 50
  }

  # Second interface: Monitor WAN (in promiscuous mode) - connect to vmbr1
  network {
    id       = 1
    model    = "virtio"
    bridge   = "vmbr1"
    firewall = false
  }

  # Third interface: Monitor Starlink WAN (in promiscuous mode) - connect to vmbr3
  network {
    id       = 2
    model    = "virtio"
    bridge   = "vmbr3"
    firewall = false
  }

  sshkeys = var.ssh_public_key

  # Make sure the secondary interfaces are in promiscuous mode
  provisioner "remote-exec" {
    inline = [
      "sudo ip link set eth1 promisc on",
      "sudo ip link set eth2 promisc on",
      "echo 'auto eth1' | sudo tee -a /etc/network/interfaces",
      "echo 'iface eth1 inet manual' | sudo tee -a /etc/network/interfaces",
      "echo '    up ip link set eth1 promisc on' | sudo tee -a /etc/network/interfaces",
      "echo 'auto eth2' | sudo tee -a /etc/network/interfaces",
      "echo 'iface eth2 inet manual' | sudo tee -a /etc/network/interfaces",
      "echo '    up ip link set eth2 promisc on' | sudo tee -a /etc/network/interfaces",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = try(file(var.ssh_private_key_file), "")
      host        = "${var.network_prefix}.50.4"
    }
  }

  # Disk configuration
  disk {
    slot         = "virtio0"
    type         = "disk"
    storage      = var.proxmox_storage
    size         = "50G"
    backup       = true
  }

  # VM settings
  onboot = true
  # Note: start_on_deploy is handled by onboot setting

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}
