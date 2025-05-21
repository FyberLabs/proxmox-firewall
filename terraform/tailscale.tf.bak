resource "proxmox_vm_qemu" "tailscale_vm" {
  name        = "tailscale-vm"
  desc        = "Tailscale VPN router"
  target_node = var.target_node
  clone       = "9001"  # ID of the Ubuntu template
  os_type     = "cloud-init"
  
  cores    = 1
  sockets  = 1
  cpu      = "host"
  memory   = 512
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"
  
  disk {
    slot    = 0
    size    = "5G"
    type    = "virtio"
    storage = "local-lvm"
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 50  # VLAN 50 for Management
  }
  
  # cloud-init settings
  ciuser     = "tailscale"
  cipassword = var.tailscale_password
  ipconfig0  = "ip=${var.network_prefix}.50.3/24,gw=${var.network_prefix}.50.1"
  
  sshkeys = var.ssh_public_key
  
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
      
      # Start Tailscale with subnet routes
      sudo tailscale up --authkey=${var.tailscale_auth_key} --advertise-routes=${var.network_prefix}.0.0/16
      
      # Create a service to ensure routes are advertised after reboot
      sudo tee /etc/systemd/system/tailscale-routes.service > /dev/null <<EOT
      [Unit]
      Description=Ensure Tailscale advertises routes
      After=tailscaled.service
      
      [Service]
      Type=oneshot
      ExecStart=/usr/bin/tailscale up --advertise-routes=${var.network_prefix}.0.0/16
      
      [Install]
      WantedBy=multi-user.target
      EOT
      
      sudo systemctl enable tailscale-routes.service
    EOF
    destination = "/tmp/setup_tailscale.sh"
    
    connection {
      type        = "ssh"
      user        = "tailscale"
      private_key = file("~/.ssh/id_rsa")
      host        = "${var.network_prefix}.50.3"
    }
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_tailscale.sh",
      "sudo /tmp/setup_tailscale.sh"
    ]
    
    connection {
      type        = "ssh"
      user        = "tailscale"
      private_key = file("~/.ssh/id_rsa")
      host        = "${var.network_prefix}.50.3"
    }
  }
}

variable "tailscale_password" {
  description = "Password for Tailscale VM"
  type        = string
  sensitive   = true
}
