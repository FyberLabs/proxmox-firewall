# Zeek Network Security Monitor VM

resource "proxmox_vm_qemu" "zeek" {
  name        = "zeek-${var.location}"
  desc        = "Zeek Network Security Monitor for ${var.location}"
  target_node = var.target_node
  clone       = var.ubuntu_template_id
  os_type     = "cloud-init"
  
  cores       = 2
  sockets     = 1
  memory      = 4096
  agent       = 1

  # Cloud-init settings
  ipconfig0   = "ip=${var.network_prefix}.50.4/24,gw=${var.network_prefix}.50.254"
  nameserver  = "${var.network_prefix}.10.1"
  searchdomain = "${var.location_domain}"
  
  # Network interfaces:
  # First interface: Management (on VLAN50)
  network {
    model    = "virtio"
    bridge   = "vmbr0"
    tag      = 50
  }
  
  # Second interface: Monitor WAN (in promiscuous mode) - connect to vmbr1
  network {
    model    = "virtio"
    bridge   = "vmbr1"
    firewall = false
  }
  
  # Third interface: Monitor Starlink WAN (in promiscuous mode) - connect to vmbr3
  network {
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
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.4"
    }
  }

  # Disk configuration
  disk {
    type         = "virtio"
    storage      = var.proxmox_storage
    size         = "50G"
    backup       = true
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
} 