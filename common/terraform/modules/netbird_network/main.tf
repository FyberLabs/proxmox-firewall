# Netbird Network Integration Module
# This module configures Netbird for secure network-to-network communication

resource "proxmox_vm_qemu" "netbird_router" {
  count       = var.enabled ? 1 : 0
  name        = "netbird-router-${var.site_name}"
  desc        = "Netbird Network Router for ${var.site_display_name}"
  target_node = var.target_node
  clone       = var.ubuntu_template_id
  os_type     = "cloud-init"

  cores    = 1
  sockets  = 1
  cpu      = "host"
  memory   = 512
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  # Cloud-init settings
  ciuser     = "netbird"
  cipassword = var.netbird_password
  ipconfig0  = "ip=${var.network_prefix}.50.6/24,gw=${var.network_prefix}.50.1"
  nameserver = "${var.network_prefix}.10.1"
  searchdomain = "${var.domain}"

  # Network interface on Management VLAN
  network {
    model    = "virtio"
    bridge   = "vmbr0"
    tag      = 50
  }

  sshkeys = var.ssh_public_key

  # Disk configuration
  disk {
    type         = "virtio"
    storage      = var.proxmox_storage
    size         = "5G"
    backup       = true
  }

  # VM settings
  agent   = 1
  onboot  = true

  # Cloud-init provisioning script
  provisioner "file" {
    content     = <<-EOF
      #!/bin/bash
      set -e

      # Install Netbird
      curl -fsSL https://pkgs.netbird.io/install.sh | sh

      # Enable IP forwarding for subnet routing
      echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
      echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
      sudo sysctl -p

      # Configure Netbird ACLs
      cat > /etc/netbird/acls.json <<EOT
      {
        "rules": [
          {
            "name": "allow-subnet",
            "action": "accept",
            "source": "${var.network_prefix}.0.0/16",
            "destination": "*"
          },
          {
            "name": "allow-management",
            "action": "accept",
            "source": "*",
            "destination": "${var.network_prefix}.50.0/24"
          }
        ]
      }
      EOT

      # Start Netbird with setup key and routes
      sudo netbird up \
        --setup-key=${var.netbird_setup_key} \
        --routes=${var.network_prefix}.0.0/16 \
        --hostname=router-${var.site_name}

      # Create a service to ensure routes are advertised after reboot
      sudo tee /etc/systemd/system/netbird-routes.service > /dev/null <<EOT
      [Unit]
      Description=Ensure Netbird advertises routes
      After=netbird.service

      [Service]
      Type=oneshot
      ExecStart=/usr/bin/netbird up \
        --setup-key=${var.netbird_setup_key} \
        --routes=${var.network_prefix}.0.0/16 \
        --hostname=router-${var.site_name}

      [Install]
      WantedBy=multi-user.target
      EOT

      sudo systemctl enable netbird-routes.service
    EOF
    destination = "/tmp/setup_netbird.sh"

    connection {
      type        = "ssh"
      user        = "netbird"
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.6"
    }
  }

  # Install and configure Netbird
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_netbird.sh",
      "sudo /tmp/setup_netbird.sh"
    ]

    connection {
      type        = "ssh"
      user        = "netbird"
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.6"
    }
  }
}

# Output the Netbird router's IP
output "netbird_router_ip" {
  value = var.enabled ? proxmox_vm_qemu.netbird_router[0].default_ipv4_address : null
  description = "IP address of the Netbird router VM"
}
