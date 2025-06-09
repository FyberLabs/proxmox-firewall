# Security Services Module
# This module deploys a VM running Pangolin (SSO) and Crowdsec for WAN access control

resource "proxmox_vm_qemu" "security_services" {
  count       = var.enabled ? 1 : 0
  name        = "security-services-${var.site_name}"
  desc        = "Security Services (Pangolin SSO + Crowdsec) for ${var.site_display_name}"
  target_node = var.target_node
  clone       = var.ubuntu_template_id
  os_type     = "cloud-init"

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }
  memory   = 4096
  scsihw   = "virtio-scsi-pci"
  bootdisk = "virtio0"

  # Cloud-init settings
  ciuser     = "security"
  cipassword = var.security_password
  ipconfig0  = "ip=${var.network_prefix}.50.8/24,gw=${var.network_prefix}.50.1"
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
    size         = "20G"
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

      # Update system
      sudo apt-get update
      sudo apt-get upgrade -y

      # Install required packages
      sudo apt-get install -y \
        docker.io \
        docker-compose \
        nginx \
        certbot \
        python3-certbot-nginx \
        fail2ban \
        ufw

      # Configure firewall
      sudo ufw allow 22/tcp
      sudo ufw allow 80/tcp
      sudo ufw allow 443/tcp
      sudo ufw allow 8080/tcp  # Pangolin SSO
      sudo ufw allow 8081/tcp  # Crowdsec dashboard
      sudo ufw --force enable

      # Create application directories
      sudo mkdir -p /opt/security-services/{pangolin,crowdsec,nginx}
      sudo chown -R security:security /opt/security-services

      # Configure Nginx
      cat > /etc/nginx/sites-available/security-services <<EOT
      server {
          listen 80;
          server_name sso.${var.domain} crowdsec.${var.domain};

          location / {
              return 301 https://\$host\$request_uri;
          }
      }

      server {
          listen 443 ssl;
          server_name sso.${var.domain};

          ssl_certificate /etc/letsencrypt/live/sso.${var.domain}/fullchain.pem;
          ssl_certificate_key /etc/letsencrypt/live/sso.${var.domain}/privkey.pem;

          location / {
              proxy_pass http://localhost:8080;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
          }
      }

      server {
          listen 443 ssl;
          server_name crowdsec.${var.domain};

          ssl_certificate /etc/letsencrypt/live/crowdsec.${var.domain}/fullchain.pem;
          ssl_certificate_key /etc/letsencrypt/live/crowdsec.${var.domain}/privkey.pem;

          location / {
              proxy_pass http://localhost:8081;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
          }
      }
      EOT

      sudo ln -sf /etc/nginx/sites-available/security-services /etc/nginx/sites-enabled/
      sudo rm -f /etc/nginx/sites-enabled/default

      # Create Docker Compose file for Pangolin
      cat > /opt/security-services/pangolin/docker-compose.yml <<EOT
      version: '3'
      services:
        pangolin:
          image: pangolin/pangolin:latest
          container_name: pangolin
          restart: unless-stopped
          environment:
            - PANGOLIN_DATABASE_URL=postgresql://pangolin:${var.pangolin_db_password}@db:5432/pangolin
            - PANGOLIN_SECRET_KEY=${var.pangolin_secret_key}
            - PANGOLIN_ALLOWED_HOSTS=sso.${var.domain}
          ports:
            - "8080:8080"
          depends_on:
            - db
          networks:
            - pangolin_net

        db:
          image: postgres:13
          container_name: pangolin_db
          restart: unless-stopped
          environment:
            - POSTGRES_USER=pangolin
            - POSTGRES_PASSWORD=${var.pangolin_db_password}
            - POSTGRES_DB=pangolin
          volumes:
            - pangolin_data:/var/lib/postgresql/data
          networks:
            - pangolin_net

      volumes:
        pangolin_data:

      networks:
        pangolin_net:
          driver: bridge
      EOT

      # Create Docker Compose file for Crowdsec
      cat > /opt/security-services/crowdsec/docker-compose.yml <<EOT
      version: '3'
      services:
        crowdsec:
          image: crowdsecurity/crowdsec:latest
          container_name: crowdsec
          restart: unless-stopped
          environment:
            - CROWDSEC_API_KEY=${var.crowdsec_api_key}
            - CROWDSEC_DB_HOST=db
            - CROWDSEC_DB_USER=crowdsec
            - CROWDSEC_DB_PASSWORD=${var.crowdsec_db_password}
          volumes:
            - /var/log:/var/log:ro
            - crowdsec_data:/var/lib/crowdsec/data
          networks:
            - crowdsec_net

        dashboard:
          image: crowdsecurity/cs-dashboard:latest
          container_name: crowdsec_dashboard
          restart: unless-stopped
          environment:
            - CROWDSEC_API_URL=http://crowdsec:8080
            - CROWDSEC_API_KEY=${var.crowdsec_api_key}
          ports:
            - "8081:8080"
          depends_on:
            - crowdsec
          networks:
            - crowdsec_net

        db:
          image: postgres:13
          container_name: crowdsec_db
          restart: unless-stopped
          environment:
            - POSTGRES_USER=crowdsec
            - POSTGRES_PASSWORD=${var.crowdsec_db_password}
            - POSTGRES_DB=crowdsec
          volumes:
            - crowdsec_db_data:/var/lib/postgresql/data
          networks:
            - crowdsec_net

      volumes:
        crowdsec_data:
        crowdsec_db_data:

      networks:
        crowdsec_net:
          driver: bridge
      EOT

      # Start services
      cd /opt/security-services/pangolin
      sudo docker-compose up -d

      cd /opt/security-services/crowdsec
      sudo docker-compose up -d

      # Get SSL certificates
      sudo certbot --nginx -d sso.${var.domain} -d crowdsec.${var.domain} --non-interactive --agree-tos --email admin@${var.domain}

      # Restart Nginx
      sudo systemctl restart nginx
    EOF
    destination = "/tmp/setup_security_services.sh"

    connection {
      type        = "ssh"
      user        = "security"
      private_key = try(file(var.ssh_private_key_file), "")
      host        = "${var.network_prefix}.50.8"
    }
  }

  # Install and configure services
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_security_services.sh",
      "sudo /tmp/setup_security_services.sh"
    ]

    connection {
      type        = "ssh"
      user        = "security"
      private_key = try(file(var.ssh_private_key_file), "")
      host        = "${var.network_prefix}.50.8"
    }
  }
}

# Outputs are defined in outputs.tf
