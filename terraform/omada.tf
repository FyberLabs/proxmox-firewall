resource "proxmox_vm_qemu" "omada_controller" {
  count       = var.vm_templates["omada"].enabled ? 1 : 0
  name        = "omada-controller"
  desc        = "Omada Controller for TP-Link APs"
  target_node = var.target_node
  clone       = "9001"  # ID of the Ubuntu template
  os_type     = "cloud-init"

  cores    = 2
  sockets  = 1
  cpu      = "host"
  memory   = 2048
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  disk {
    slot    = 0
    size    = "10G"
    type    = "virtio"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 50  # VLAN 50 for Management
  }

  # cloud-init settings
  ciuser     = "omada"
  cipassword = var.omada_password
  cicustom   = "user=local:snippets/omada-cloud-init.yml"
  ipconfig0  = "ip=${var.network_prefix}.50.2/24,gw=${var.network_prefix}.50.1"

  sshkeys = var.ssh_public_key

  # VM settings
  agent   = 1
  onboot  = true
  oncreate = var.vm_templates["omada"].start_on_deploy

  # Cloud-init provisioning script
  provisioner "file" {
    source      = "${path.module}/scripts/install_omada.sh"
    destination = "/tmp/install_omada.sh"

    connection {
      type        = "ssh"
      user        = "omada"
      private_key = file("~/.ssh/id_rsa")
      host        = "${var.network_prefix}.50.2"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_omada.sh",
      "sudo /tmp/install_omada.sh"
    ]

    connection {
      type        = "ssh"
      user        = "omada"
      private_key = file("~/.ssh/id_rsa")
      host        = "${var.network_prefix}.50.2"
    }
  }
}

variable "omada_password" {
  description = "Password for Omada VM"
  type        = string
  sensitive   = true
}
