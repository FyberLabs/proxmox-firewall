#!/bin/bash
# Site Deployment Script
# This script handles deployment of a Proxmox firewall configuration to a specific site

set -e

# Default values
PLAYBOOK_DIR="$(dirname "$(dirname "$0")")/ansible"
INVENTORY_FILE="$PLAYBOOK_DIR/inventory/hosts.yml"
SITE_NAME=""
TARGET_IP=""
TAGS="all"
DRY_RUN=false
VERBOSE=false
OPERATION="deploy"

# Help function
function show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -s, --site SITE_NAME     Site name to deploy (required unless -i is used)"
    echo "  -i, --ip TARGET_IP       Target IP address (required unless -s is used)"
    echo "  -o, --operation TYPE     Operation type: deploy, network, security (default: deploy)"
    echo "  -t, --tags TAGS          Ansible tags to run (default: all)"
    echo "  -d, --dry-run            Perform a dry run (no changes made)"
    echo "  -v, --verbose            Enable verbose output"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --site primary              # Deploy to the 'primary' site"
    echo "  $0 --ip 192.168.1.10           # Deploy to host at specific IP"
    echo "  $0 --site office --tags network # Only configure network for 'office' site"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -s|--site)
            SITE_NAME="$2"
            shift 2
            ;;
        -i|--ip)
            TARGET_IP="$2"
            shift 2
            ;;
        -o|--operation)
            OPERATION="$2"
            shift 2
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate arguments
if [[ -z "$SITE_NAME" && -z "$TARGET_IP" ]]; then
    echo "Error: Either site name (-s) or target IP (-i) must be provided."
    exit 1
fi

# Determine site name from IP if needed
if [[ -z "$SITE_NAME" && -n "$TARGET_IP" ]]; then
    echo "Attempting to determine site name from target IP: $TARGET_IP"

    # Check if we can ping the target
    if ! ping -c 1 -W 2 "$TARGET_IP" > /dev/null 2>&1; then
        echo "Error: Cannot reach target at $TARGET_IP"
        exit 1
    fi

    # Try to SSH to the target and get hostname
    if SSH_HOSTNAME=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$TARGET_IP" hostname 2>/dev/null); then
        SITE_NAME=$(echo "$SSH_HOSTNAME" | cut -d'-' -f1)
        echo "Determined site name from hostname: $SITE_NAME"
    else
        echo "Warning: Could not determine site name automatically."
        echo "Please specify a site name with -s option."
        exit 1
    fi
fi

# Set Ansible command based on operation type
ANSIBLE_CMD="ansible-playbook"
ANSIBLE_ARGS=()

if [[ "$VERBOSE" == true ]]; then
    ANSIBLE_ARGS+=("-v")
fi

if [[ "$DRY_RUN" == true ]]; then
    ANSIBLE_ARGS+=("--check")
fi

# Set the playbook and tags based on operation
case "$OPERATION" in
    deploy)
        PLAYBOOK="$PLAYBOOK_DIR/playbooks/site_deployment.yml"
        ;;
    network)
        PLAYBOOK="$PLAYBOOK_DIR/playbooks/site_deployment.yml"
        TAGS="network"
        ;;
    security)
        PLAYBOOK="$PLAYBOOK_DIR/playbooks/site_deployment.yml"
        TAGS="security,opnsense,zeek"
        ;;
    *)
        echo "Error: Unknown operation type: $OPERATION"
        exit 1
        ;;
esac

# Display deployment information
echo "=============================================="
echo "Proxmox Firewall Site Deployment"
echo "=============================================="
echo "Site: $SITE_NAME"
if [[ -n "$TARGET_IP" ]]; then
    echo "Target IP: $TARGET_IP"
    # Add the IP to the extra vars
    ANSIBLE_ARGS+=("-e" "target_ip=$TARGET_IP")
fi
echo "Operation: $OPERATION"
echo "Tags: $TAGS"
if [[ "$DRY_RUN" == true ]]; then
    echo "Mode: DRY RUN (no changes will be made)"
fi
echo "=============================================="

# Set site name in extra vars
ANSIBLE_ARGS+=("-e" "site=$SITE_NAME")

# Set tags if specified
if [[ "$TAGS" != "all" ]]; then
    ANSIBLE_ARGS+=("--tags" "$TAGS")
fi

# Run the playbook
echo "Starting deployment... ($(date))"
$ANSIBLE_CMD $PLAYBOOK "${ANSIBLE_ARGS[@]}"
RESULT=$?

if [[ $RESULT -eq 0 ]]; then
    echo "=============================================="
    echo "Deployment completed successfully! ($(date))"
    echo "=============================================="
else
    echo "=============================================="
    echo "Deployment failed with exit code $RESULT ($(date))"
    echo "=============================================="
    exit $RESULT
fi
