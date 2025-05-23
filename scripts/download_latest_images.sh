#!/bin/bash

# Script to validate image downloads and their signatures/certificates
# This script verifies the integrity and authenticity of downloaded images

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration directories
IMAGES_DIR="images"
LOGS_DIR="logs"
KEYS_DIR="keys"
ANSIBLE_VARS_DIR="ansible/group_vars"

# Create required directories
mkdir -p "$IMAGES_DIR" "$LOGS_DIR" "$KEYS_DIR" "$ANSIBLE_VARS_DIR"

# Log file with timestamp
LOG_FILE="$LOGS_DIR/image_validation_$(date +%Y%m%d_%H%M%S).log"

# Initialize JSON output file
echo "{}" > "$ANSIBLE_VARS_DIR/validated_images.json"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command '$1' not found"
        exit 1
    fi
}

# Update JSON with validated image info
update_json() {
    local key=$1
    local value=$2
    local temp_file=$(mktemp)
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$ANSIBLE_VARS_DIR/validated_images.json" > "$temp_file"
    mv "$temp_file" "$ANSIBLE_VARS_DIR/validated_images.json"
}

# Check required commands
check_command "curl"
check_command "gpg"
check_command "sha256sum"
check_command "openssl"
check_command "jq"

# Get latest Ubuntu LTS version
get_latest_ubuntu_lts() {
    local releases_url="https://releases.ubuntu.com/"
    local latest_lts=$(curl -s "$releases_url" | grep -oP 'href="\K[0-9]{2}\.[0-9]{2}(?=/")' | sort -V | grep -E '^[0-9]{2}\.[0-9]{2}$' | tail -n1)
    echo "$latest_lts"
}

# Download and verify Ubuntu cloud image
validate_ubuntu_image() {
    local version=$1
    local arch="amd64"
    local image_name="ubuntu-${version}-server-cloudimg-${arch}.img"
    local image_url="https://cloud-images.ubuntu.com/${version}/current/${image_name}"
    local sha256_url="${image_url}.SHA256SUMS"
    local signature_url="${image_url}.SHA256SUMS.gpg"

    log_info "Validating Ubuntu ${version} cloud image"

    # Download image and checksums
    curl -L -o "$IMAGES_DIR/$image_name" "$image_url"
    curl -L -o "$IMAGES_DIR/${image_name}.SHA256SUMS" "$sha256_url"
    curl -L -o "$IMAGES_DIR/${image_name}.SHA256SUMS.gpg" "$signature_url"

    # Verify GPG signature
    if ! gpg --verify "$IMAGES_DIR/${image_name}.SHA256SUMS.gpg" "$IMAGES_DIR/${image_name}.SHA256SUMS"; then
        log_error "GPG signature verification failed for Ubuntu ${version}"
        return 1
    fi

    # Verify SHA256 checksum
    if ! (cd "$IMAGES_DIR" && sha256sum -c "${image_name}.SHA256SUMS" 2>/dev/null | grep -q "$image_name: OK"); then
        log_error "SHA256 checksum verification failed for Ubuntu ${version}"
        return 1
    fi

    # Update JSON with Ubuntu image info
    update_json "ubuntu_version" "$version"
    update_json "ubuntu_image_path" "$IMAGES_DIR/$image_name"

    log_info "Ubuntu ${version} cloud image validation successful"
    return 0
}

# Download and verify OPNsense image
validate_opnsense_image() {
    log_info "Finding latest OPNsense release..."
    # Get the latest version from the releases page
    local latest_version=$(curl -s https://opnsense.org/download/ | grep -oP 'OPNsense-[0-9]+\.[0-9]+' | sort -V | tail -n1 | cut -d'-' -f2)
    local arch="amd64"
    local image_name="OPNsense-${latest_version}-OpenSSL-${arch}.img"
    local image_url="https://mirror.ams1.nl.leaseweb.net/opnsense/releases/${latest_version}/${image_name}"
    local sha256_url="${image_url}.sha256"
    local signature_url="${image_url}.sig"

    log_info "Found latest version: ${latest_version}"

    # Download image and checksums
    curl -L -o "$IMAGES_DIR/$image_name" "$image_url"
    curl -L -o "$IMAGES_DIR/${image_name}.sha256" "$sha256_url"
    curl -L -o "$IMAGES_DIR/${image_name}.sig" "$signature_url"

    # Import OPNsense public key if not already imported
    if ! gpg --list-keys "OPNsense <security@opnsense.org>" &>/dev/null; then
        curl -fsSL https://opnsense.org/opnsense.gpg | gpg --dearmor -o "$KEYS_DIR/opnsense.gpg"
        gpg --import "$KEYS_DIR/opnsense.gpg"
    fi

    # Verify SHA256 checksum
    if ! (cd "$IMAGES_DIR" && sha256sum -c "${image_name}.sha256" 2>/dev/null | grep -q "$image_name: OK"); then
        log_error "SHA256 checksum verification failed for OPNsense ${latest_version}"
        return 1
    fi

    # Verify signature
    if ! openssl dgst -sha256 -verify "$KEYS_DIR/opnsense.pub" -signature "$IMAGES_DIR/${image_name}.sig" "$IMAGES_DIR/$image_name"; then
        log_error "Signature verification failed for OPNsense ${latest_version}"
        return 1
    fi

    # Update JSON with OPNsense image info
    update_json "opnsense_version" "$latest_version"
    update_json "opnsense_image_path" "$IMAGES_DIR/$image_name"

    log_info "OPNsense ${latest_version} image validation successful"
    return 0
}

# Download and verify Proxmox ISO
validate_proxmox_iso() {
    log_info "Finding latest Proxmox VE ISO..."
    local latest_iso=$(curl -s https://download.proxmox.com/iso/ | grep -o 'proxmox-ve_[0-9]\+\.[0-9]\+-[0-9]\+\.iso' | sort -V | tail -n 1)
    local iso_url="https://download.proxmox.com/iso/$latest_iso"
    local sha256_url="${iso_url}.sha256sum"
    local signature_url="${iso_url}.sha256sum.sig"

    log_info "Found latest version: $latest_iso"

    # Download ISO and checksums
    curl -L -o "$IMAGES_DIR/$latest_iso" "$iso_url"
    curl -L -o "$IMAGES_DIR/${latest_iso}.sha256sum" "$sha256_url"
    curl -L -o "$IMAGES_DIR/${latest_iso}.sha256sum.sig" "$signature_url"

    # Import Proxmox public key if not already imported
    if ! gpg --list-keys "Proxmox Support Team <support@proxmox.com>" &>/dev/null; then
        curl -fsSL https://download.proxmox.com/debian/proxmox-release-bullseye.gpg | gpg --dearmor -o "$KEYS_DIR/proxmox.gpg"
        gpg --import "$KEYS_DIR/proxmox.gpg"
    fi

    # Verify GPG signature
    if ! gpg --verify "$IMAGES_DIR/${latest_iso}.sha256sum.sig" "$IMAGES_DIR/${latest_iso}.sha256sum"; then
        log_error "GPG signature verification failed for Proxmox VE ISO"
        return 1
    fi

    # Verify SHA256 checksum
    if ! (cd "$IMAGES_DIR" && sha256sum -c "${latest_iso}.sha256sum" 2>/dev/null | grep -q "$latest_iso: OK"); then
        log_error "SHA256 checksum verification failed for Proxmox VE ISO"
        return 1
    fi

    # Update JSON with Proxmox ISO info
    update_json "proxmox_version" "$latest_iso"
    update_json "proxmox_iso_path" "$IMAGES_DIR/$latest_iso"

    log_info "Proxmox VE ISO validation successful"
    return 0
}

# Download and verify Docker images
validate_docker_image() {
    local image=$1
    local tag=$2
    local full_image="${image}:${tag}"

    log_info "Validating Docker image: $full_image"

    # Pull the image
    if ! docker pull "$full_image"; then
        log_error "Failed to pull Docker image: $full_image"
        return 1
    fi

    # Verify image digest
    if ! docker inspect --format='{{.RepoDigests}}' "$full_image" | grep -q "@sha256:"; then
        log_error "No digest found for Docker image: $full_image"
        return 1
    fi

    # Get image digest
    local digest=$(docker inspect --format='{{.RepoDigests}}' "$full_image" | grep -o '@sha256:[a-f0-9]*')

    # Update JSON with Docker image info
    update_json "docker_${image//\//_}_${tag}" "$full_image$digest"

    log_info "Docker image validation successful: $full_image"
    return 0
}

# Main validation function
validate_all_images() {
    local failed=0

    # Get and validate latest Ubuntu LTS
    local latest_ubuntu_lts=$(get_latest_ubuntu_lts)
    log_info "Latest Ubuntu LTS version: ${latest_ubuntu_lts}"
    if ! validate_ubuntu_image "$latest_ubuntu_lts"; then
        failed=1
    fi

    # Validate OPNsense image
    if ! validate_opnsense_image; then
        failed=1
    fi

    # Validate Proxmox ISO
    if ! validate_proxmox_iso; then
        failed=1
    fi

    # Validate Docker images
    local docker_images=(
        "pangolin/pangolin:latest"
        "crowdsecurity/crowdsec:latest"
        "crowdsecurity/cs-dashboard:latest"
        "postgres:13"
    )

    for image in "${docker_images[@]}"; do
        if ! validate_docker_image "${image%:*}" "${image#*:}"; then
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        log_info "All image validations completed successfully"
        log_info "Validated image information written to $ANSIBLE_VARS_DIR/validated_images.json"
        exit 0
    else
        log_error "Some image validations failed"
        exit 1
    fi
}

# Run main validation function
validate_all_images
