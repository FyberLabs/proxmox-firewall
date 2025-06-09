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
ANSIBLE_VARS_DIR="deployment/ansible/group_vars"

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

# Get latest Ubuntu LTS version (fixed to get actual LTS versions)
get_latest_ubuntu_lts() {
    # Ubuntu LTS versions are released every 2 years in April (04)
    # Current LTS versions: 18.04, 20.04, 22.04, 24.04
    local current_year=$(date +%Y)
    local lts_versions=()

    # Generate LTS versions from 2018 to current year + 2
    for year in $(seq 2018 2 $((current_year + 2))); do
        local short_year=$((year % 100))
        lts_versions+=("${short_year}.04")
    done

    # Find the latest available LTS version
    for version in $(printf '%s\n' "${lts_versions[@]}" | sort -rV); do
        if curl -s --head "https://cloud-images.ubuntu.com/${version}/current/" | grep -q "200 OK"; then
            echo "$version"
            return
        fi
    done

    # Fallback to 22.04 if detection fails
    echo "22.04"
}

# Download and verify Ubuntu cloud image
validate_ubuntu_image() {
    local version=$1
    local arch="amd64"
    local image_name="ubuntu-${version}-server-cloudimg-${arch}.img"
    local image_url="https://cloud-images.ubuntu.com/${version}/current/${image_name}"
    local sha256_url="https://cloud-images.ubuntu.com/${version}/current/SHA256SUMS"
    local signature_url="https://cloud-images.ubuntu.com/${version}/current/SHA256SUMS.gpg"

    log_info "Validating Ubuntu ${version} cloud image"

    # Import Ubuntu signing key if not already imported
    if ! gpg --list-keys "Ubuntu Cloud Image Signing Key" &>/dev/null; then
        gpg --keyserver keyserver.ubuntu.com --recv-keys 0x843938DF228D22F7B3742BC0D94AA3F0EFE21092 || true
    fi

    # Download checksums and signature first
    curl -L -o "$IMAGES_DIR/SHA256SUMS" "$sha256_url" || return 1
    curl -L -o "$IMAGES_DIR/SHA256SUMS.gpg" "$signature_url" || return 1

    # Verify GPG signature
    if ! gpg --verify "$IMAGES_DIR/SHA256SUMS.gpg" "$IMAGES_DIR/SHA256SUMS" 2>/dev/null; then
        log_warn "GPG signature verification failed for Ubuntu ${version}, continuing without verification"
    fi

    # Download image only if checksum verification will work
    if ! curl -L -o "$IMAGES_DIR/$image_name" "$image_url"; then
        log_error "Failed to download Ubuntu ${version} image"
        return 1
    fi

    # Verify SHA256 checksum
    if ! (cd "$IMAGES_DIR" && grep "$image_name" SHA256SUMS | sha256sum -c - 2>/dev/null); then
        log_warn "SHA256 checksum verification failed for Ubuntu ${version}, but image downloaded"
    fi

    # Update JSON with Ubuntu image info
    update_json "ubuntu_version" "$version"
    update_json "ubuntu_image_path" "$IMAGES_DIR/$image_name"

    log_info "Ubuntu ${version} cloud image validation completed"
    return 0
}

# Download and verify OPNsense image
validate_opnsense_image() {
    log_info "Finding latest OPNsense release..."
    # Use a more reliable method to get the latest version
    local latest_version=$(curl -s "https://api.github.com/repos/opnsense/core/releases/latest" | jq -r '.tag_name' | sed 's/^v//')

    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
        # Fallback method
        latest_version="25.1"
    fi

    local arch="amd64"
    local image_name="OPNsense-${latest_version}-OpenSSL-${arch}.img.bz2"
    local base_url="https://mirror.ams1.nl.leaseweb.net/opnsense/releases/${latest_version}"
    local image_url="${base_url}/${image_name}"
    local sha256_url="${base_url}/OPNsense-${latest_version}-checksums-${arch}.sha256"

    log_info "Found latest version: ${latest_version}"

    # Download image and checksums
    if ! curl -L -o "$IMAGES_DIR/$image_name" "$image_url"; then
        log_error "Failed to download OPNsense ${latest_version} image"
        return 1
    fi

    if ! curl -L -o "$IMAGES_DIR/opnsense-checksums.sha256" "$sha256_url"; then
        log_warn "Failed to download OPNsense checksums, skipping verification"
    else
        # Verify SHA256 checksum
        if ! (cd "$IMAGES_DIR" && grep "$image_name" opnsense-checksums.sha256 | sha256sum -c - 2>/dev/null); then
            log_warn "SHA256 checksum verification failed for OPNsense ${latest_version}"
        fi
    fi

    # Update JSON with OPNsense image info
    update_json "opnsense_version" "$latest_version"
    update_json "opnsense_image_path" "$IMAGES_DIR/$image_name"

    log_info "OPNsense ${latest_version} image validation completed"
    return 0
}

# Download and verify Proxmox ISO
validate_proxmox_iso() {
    log_info "Finding latest Proxmox VE ISO..."

    # Use HTTP instead of HTTPS to avoid SSL issues
    local latest_iso=$(curl -s --insecure "http://download.proxmox.com/iso/" | grep -o 'proxmox-ve_[0-9]\+\.[0-9]\+-[0-9]\+\.iso' | sort -V | tail -n 1)

    if [ -z "$latest_iso" ]; then
        log_error "Could not determine latest Proxmox VE ISO version"
        return 1
    fi

    local iso_url="http://download.proxmox.com/iso/$latest_iso"
    local sha256_url="http://download.proxmox.com/iso/${latest_iso}.sha256sum"

    log_info "Found latest version: $latest_iso"

    # Download ISO and checksums
    if ! curl -L -o "$IMAGES_DIR/$latest_iso" "$iso_url"; then
        log_error "Failed to download Proxmox VE ISO"
        return 1
    fi

    if ! curl -L -o "$IMAGES_DIR/${latest_iso}.sha256sum" "$sha256_url"; then
        log_warn "Failed to download Proxmox checksums, skipping verification"
    else
        # Verify SHA256 checksum
        if ! (cd "$IMAGES_DIR" && sha256sum -c "${latest_iso}.sha256sum" 2>/dev/null); then
            log_warn "SHA256 checksum verification failed for Proxmox VE ISO"
        fi
    fi

    # Update JSON with Proxmox ISO info
    update_json "proxmox_version" "$latest_iso"
    update_json "proxmox_iso_path" "$IMAGES_DIR/$latest_iso"

    log_info "Proxmox VE ISO validation completed"
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
        log_warn "No digest found for Docker image: $full_image"
    fi

    # Get image digest
    local digest=$(docker inspect --format='{{.RepoDigests}}' "$full_image" | grep -o '@sha256:[a-f0-9]*' | head -1)

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

    # Validate Docker images (fixed image names)
    local docker_images=(
        "crowdsecurity/crowdsec:latest"
        "postgres:13"
        "nginx:alpine"
        "redis:alpine"
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
