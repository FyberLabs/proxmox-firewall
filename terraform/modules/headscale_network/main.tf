# Headscale Network Integration Module
# This module configures a self-hosted Headscale server for secure network-to-network communication

resource "proxmox_vm_qemu" "headscale_server" {
  count       = var.enabled ? 1 : 0
  name        = "headscale-server-${var.site_name}"
  desc        = "Headscale Control Server for ${var.site_display_name}"
  target_node = var.target_node
  clone       = var.ubuntu_template_id
  os_type     = "cloud-init"

  cores    = 2
  sockets  = 1
  cpu      = "host"
  memory   = 2048
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  # Cloud-init settings
  ciuser     = "headscale"
  cipassword = var.headscale_password
  ipconfig0  = "ip=${var.network_prefix}.50.7/24,gw=${var.network_prefix}.50.1"
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
    size         = "10G"
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

      # Install Headscale
      curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
      curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
      sudo apt-get update
      sudo apt-get install -y headscale

      # Create Headscale configuration directory
      sudo mkdir -p /etc/headscale

      # Configure Headscale
      cat > /etc/headscale/config.yaml <<EOT
      server_url: https://headscale.${var.domain}
      listen_addr: 0.0.0.0:50443
      metrics_listen_addr: 0.0.0.0:50444
      grpc_listen_addr: 0.0.0.0:50445
      private_key_path: /var/lib/headscale/private.key
      noise:
        private_key_path: /var/lib/headscale/noise_private.key
      db_type: sqlite3
      db_path: /var/lib/headscale/db.sqlite
      dns_config:
        nameservers:
          - ${var.network_prefix}.10.1
        domains: []
        magic_dns: false
        base_domain: ${var.domain}
      unix_socket: /var/run/headscale/headscale.sock
      unix_socket_permission: "0770"
      log:
        level: info
      acl_policy_path: /etc/headscale/acls.yaml
      derp:
        server:
          enabled: true
          region_id: 999
          stun_listen_addr: "0.0.0.0:3478"
        regions:
          999:
            regionid: 999
            regioncode: "self"
            regionname: "Self-hosted"
            nodes:
              - name: "derp1"
                regionid: 999
                hostname: "headscale.${var.domain}"
                ipv4: "${var.network_prefix}.50.7"
                stunport: 3478
                stunonly: false
      EOT

      # Configure Headscale ACLs
      cat > /etc/headscale/acls.yaml <<EOT
      acls:
        - action: accept
          src: ["${var.network_prefix}.0.0/16"]
          dst: ["*:*"]
        - action: accept
          src: ["*"]
          dst: ["${var.network_prefix}.50.0/24:*"]
      EOT

      # Create systemd service
      cat > /etc/systemd/system/headscale.service <<EOT
      [Unit]
      Description=headscale - A Tailscale control server
      After=network.target

      [Service]
      Type=simple
      User=headscale
      Group=headscale
      ExecStart=/usr/bin/headscale serve
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
      EOT

      # Create user and set permissions
      sudo useradd -m -d /var/lib/headscale headscale
      sudo mkdir -p /var/lib/headscale
      sudo chown -R headscale:headscale /var/lib/headscale
      sudo chmod 700 /var/lib/headscale

      # Initialize Headscale
      sudo headscale init

      # Create API key
      sudo headscale apikeys create -e 365d > /tmp/api_key.txt

      # Start and enable Headscale
      sudo systemctl enable headscale
      sudo systemctl start headscale

      # Create preauth key for routers
      sudo headscale preauthkeys create -e 365d -o json > /tmp/preauth_key.json
    EOF
    destination = "/tmp/setup_headscale.sh"

    connection {
      type        = "ssh"
      user        = "headscale"
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.7"
    }
  }

  # Install and configure Headscale
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_headscale.sh",
      "sudo /tmp/setup_headscale.sh"
    ]

    connection {
      type        = "ssh"
      user        = "headscale"
      private_key = file(var.ssh_private_key_file)
      host        = "${var.network_prefix}.50.7"
    }
  }
}

# Output the Headscale server's IP
output "headscale_server_ip" {
  value = var.enabled ? proxmox_vm_qemu.headscale_server[0].default_ipv4_address : null
  description = "IP address of the Headscale server VM"
}
