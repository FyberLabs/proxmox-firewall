#!/bin/bash
set -e

# Load .env for secrets
source .env

# Install required tools (if not already present)
# Add the Proxmox VE repository as root:
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list

# Import the Proxmox VE signing key:
sudo wget http://download.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

sudo apt update
sudo apt install -y whois proxmox-auto-install-assistant xorriso curl pipx

#Local install of ansible and ansible-dev-tools
pipx ensurepath
pipx install --include-deps ansible
pipx install ansible-dev-tools ansible-lint httpx
ansible-galaxy collection install -r ansible/collections/requirements.yml

# Get validated Proxmox ISO information
if [ ! -f "ansible/group_vars/validated_images.json" ]; then
    echo "Error: Validated images JSON file not found. Please run validate_images.sh first."
    exit 1
fi

PROXMOX_ISO_PATH=$(jq -r '.proxmox_iso_path' "ansible/group_vars/validated_images.json")
if [ "$PROXMOX_ISO_PATH" = "null" ] || [ ! -f "$PROXMOX_ISO_PATH" ]; then
    echo "Error: Validated Proxmox ISO not found. Please run validate_images.sh first."
    exit 1
fi

echo "Using validated Proxmox ISO: $PROXMOX_ISO_PATH"

ISO_NAME="proxmox-ve-custom.iso"
TMP_DIR="/tmp/proxmox-iso"
mkdir -p "$TMP_DIR"

# Copy validated ISO to temp directory
cp "$PROXMOX_ISO_PATH" "$TMP_DIR/proxmox-original.iso"

ROOT_HASHED_PASSWORD=$(mkpasswd $ROOT_PASSWORD)

# Create answer.toml with thin LVM and .env secrets
cat <<EOF > "$TMP_DIR/answer.toml"
[global]
keyboard = "en-us"
country = "us"
timezone = "UTC"
root-password = "$ROOT_HASHED_PASSWORD"
mailto = "$ADMIN_EMAIL"
fqdn.source = "from-dhcp"
fqdn.domain = "$FQDN_LOCAL"

[network]
source = "from-dhcp"

[disk-setup]
filesystem = "ext4"
lvm.swapsize = 8
lvm.maxroot = 32
disk-list = ['sda']

EOF

# Prepare the ISO with the answer file
proxmox-auto-install-assistant prepare-iso \
    "$TMP_DIR/proxmox-original.iso" \
    --fetch-from iso \
    --answer-file "$TMP_DIR/answer.toml" \
    --output "$ISO_NAME"

# Cleanup
rm -rf "$TMP_DIR"
echo "Custom ISO created: $ISO_NAME"
