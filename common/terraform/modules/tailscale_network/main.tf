# Tailscale Network Integration Module
# This module configures Tailscale for secure network-to-network communication

resource "proxmox_vm_qemu" "tailscale_router" {
  count       = var.enabled ? 1 : 0
  name        = "tailscale-router-${var.site_name}"
  desc        = "Tailscale Network Router for ${var.site_display_name}"
  target_node = var.target_node
  clone       = var.ubuntu_template_id
  os_type     = "cloud-init"

  cpu {
    cores   = 1
    sockets = 1
    type    = "host"
  }
  memory   = 512
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  # Cloud-init settings
  ciuser     = "tailscale"
  cipassword = var.tailscale_password
  ipconfig0  = "ip=${var.network_prefix}.50.5/24,gw=${var.network_prefix}.50.1"
  nameserver = "${var.network_prefix}.10.1"
  searchdomain = "${var.domain}"

  # Network interface on Management VLAN
  network {
    id       = 0
    model    = "virtio"
    bridge   = "vmbr0"
    tag      = 50
  }

  sshkeys = var.ssh_public_key

  # Disk configuration
  disk {
    slot         = "virtio0"
    type         = "disk"
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

      # Install Tailscale
      curl -fsSL https://tailscale.com/install.sh | sh

      # Enable IP forwarding for subnet routing
      echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
      echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
      sudo sysctl -p

      # Configure Tailscale ACLs
      cat > /etc/tailscale/acls.json <<EOT
      {
        "acls": [
          {
            "action": "accept",
            "src": ["${var.network_prefix}.0.0/16"],
            "dst": ["*:*"]
          },
          {
            "action": "accept",
            "src": ["*"],
            "dst": ["${var.network_prefix}.50.0/24:*"]
          }
        ]
      }
      EOT

      # Start Tailscale with subnet routes and ACLs
      sudo tailscale up \
        --authkey=${var.tailscale_auth_key} \
        --advertise-routes=${var.network_prefix}.0.0/16 \
        --hostname=router-${var.site_name} \
        --accept-routes=true \
        --advertise-exit-node=true

      # Create a service to ensure routes are advertised after reboot
      sudo tee /etc/systemd/system/tailscale-routes.service > /dev/null <<EOT
      [Unit]
      Description=Ensure Tailscale advertises routes
      After=tailscaled.service

      [Service]
      Type=oneshot
      ExecStart=/usr/bin/tailscale up \
        --authkey=${var.tailscale_auth_key} \
        --advertise-routes=${var.network_prefix}.0.0/16 \
        --hostname=router-${var.site_name} \
        --accept-routes=true \
        --advertise-exit-node=true

      [Install]
      WantedBy=multi-user.target
      EOT

      sudo systemctl enable tailscale-routes.service
    EOF
    destination = "/tmp/setup_tailscale.sh"

    connection {
      type        = "ssh"
      user        = "tailscale"
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.5"
    }
  }

  # Install and configure Tailscale
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_tailscale.sh",
      "sudo /tmp/setup_tailscale.sh"
    ]

    connection {
      type        = "ssh"
      user        = "tailscale"
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.5"
    }
  }
}

# Outputs are defined in outputs.tf
