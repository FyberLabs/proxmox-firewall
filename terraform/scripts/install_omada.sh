#!/bin/bash
set -e

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y openjdk-17-jre-headless curl wget jsvc mongodb

# Install Omada Controller
OMADA_VER="5.9.31"
OMADA_DEB="omada_v${OMADA_VER}_linux_x64.deb"

cd /tmp
wget https://static.tp-link.com/upload/software/2023/202305/20230511/${OMADA_DEB}
dpkg -i ${OMADA_DEB} || true
apt -f install -y

# Enable and start the service
systemctl enable omada
systemctl start omada

echo "Omada Controller installed and started!"
