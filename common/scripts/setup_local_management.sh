#!/bin/bash

# Setup Local Management on Proxmox Server
# This script configures the Proxmox server to manage its own configuration
# by cloning the user's fork and setting up local Terraform state management

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_DIR="/opt/proxmox-firewall"
STATE_DIR="/opt/proxmox-firewall/terraform-state"
BACKUP_DIR="/opt/proxmox-firewall-backups"
LOG_DIR="/var/log/proxmox-firewall"
CRON_USER="root"
UPDATE_SCHEDULE="*/15 * * * *"  # Every 15 minutes

# Function to log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_DIR}/setup.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_DIR}/setup.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_DIR}/setup.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_DIR}/setup.log"
}

# Function to check if running on Proxmox
check_proxmox() {
    if ! command -v pveversion &> /dev/null; then
        log_error "This script must be run on a Proxmox VE server"
        exit 1
    fi

    log_info "Detected Proxmox VE: $(pveversion --verbose | head -1)"
}

# Function to validate parameters
validate_params() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <git_repo_url> <site_name> [git_branch]"
        echo ""
        echo "Examples:"
        echo "  $0 https://github.com/username/proxmox-firewall.git primary"
        echo "  $0 git@github.com:username/proxmox-firewall.git secondary main"
        echo ""
        echo "Parameters:"
        echo "  git_repo_url: Your fork's git repository URL"
        echo "  site_name:    Site name from config/sites/<site_name>.yml"
        echo "  git_branch:   Git branch to track (default: main)"
        exit 1
    fi

    GIT_REPO_URL="$1"
    SITE_NAME="$2"
    GIT_BRANCH="${3:-main}"

    log_info "Configuration:"
    log_info "  Repository: $GIT_REPO_URL"
    log_info "  Site Name: $SITE_NAME"
    log_info "  Branch: $GIT_BRANCH"
}

# Function to setup directories
setup_directories() {
    log_info "Setting up directories..."

    # Create main directories
    mkdir -p "$REPO_DIR"
    mkdir -p "$STATE_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"

    # Set permissions
    chmod 750 "$REPO_DIR"
    chmod 700 "$STATE_DIR"
    chmod 755 "$BACKUP_DIR"
    chmod 755 "$LOG_DIR"

    log_success "Directories created and configured"
}

# Function to install dependencies
install_dependencies() {
    log_info "Installing required dependencies..."

    # Update package list
    apt-get update -q

    # Install git if not present
    if ! command -v git &> /dev/null; then
        apt-get install -y git
        log_success "Git installed"
    fi

    # Install jq for JSON processing
    if ! command -v jq &> /dev/null; then
        apt-get install -y jq
        log_success "jq installed"
    fi

    # Install terraform if not present
    if ! command -v terraform &> /dev/null; then
        log_info "Installing Terraform..."
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        apt-get update -q
        apt-get install -y terraform
        log_success "Terraform installed: $(terraform version | head -1)"
    fi

    # Install ansible if not present
    if ! command -v ansible &> /dev/null; then
        log_info "Installing Ansible..."
        apt-get install -y software-properties-common
        add-apt-repository --yes --update ppa:ansible/ansible
        apt-get install -y ansible
        log_success "Ansible installed: $(ansible --version | head -1)"
    fi
}

# Function to clone repository
clone_repository() {
    log_info "Cloning repository..."

    if [[ -d "$REPO_DIR/.git" ]]; then
        log_warning "Repository already exists, updating..."
        cd "$REPO_DIR"
        git fetch origin
        git reset --hard "origin/$GIT_BRANCH"
        git clean -fd
    else
        log_info "Cloning fresh repository..."
        git clone "$GIT_REPO_URL" "$REPO_DIR"
        cd "$REPO_DIR"
        git checkout "$GIT_BRANCH"
    fi

    # Verify site configuration exists
    if [[ ! -f "config/sites/${SITE_NAME}.yml" ]]; then
        log_error "Site configuration not found: config/sites/${SITE_NAME}.yml"
        log_error "Available sites:"
        ls -1 config/sites/*.yml 2>/dev/null | sed 's/.*\///;s/\.yml$//' | sed 's/^/  - /' || echo "  No site configurations found"
        exit 1
    fi

    log_success "Repository cloned and validated"
}

# Function to setup Terraform state management
setup_terraform_state() {
    log_info "Setting up Terraform state management..."

    cd "$REPO_DIR"

    # Create terraform state backend configuration
    cat > terraform-state-backend.tf <<EOF
# Local Terraform State Backend Configuration
# This file configures Terraform to store state locally on the Proxmox server

terraform {
  backend "local" {
    path = "${STATE_DIR}/terraform.tfstate"
  }
}
EOF

    # Initialize Terraform with local state
    if [[ -d "common/terraform" ]]; then
        cd common/terraform
        terraform init -reconfigure
        log_success "Terraform initialized with local state backend"
    else
        log_warning "Terraform directory not found, will initialize on first run"
    fi

    cd "$REPO_DIR"
}

# Function to setup environment configuration
setup_environment() {
    log_info "Setting up environment configuration..."

    cd "$REPO_DIR"

    # Create local environment file if it doesn't exist
    if [[ ! -f ".env" ]]; then
        cp env.example .env
        log_info "Created .env from template - PLEASE CONFIGURE BEFORE FIRST RUN"
    fi

    # Create site-specific environment override
    cat > ".env.${SITE_NAME}" <<EOF
# Site-specific environment overrides for ${SITE_NAME}
# This file is loaded after .env and can override settings

# Site identification
CURRENT_SITE_NAME="${SITE_NAME}"
TERRAFORM_STATE_PATH="${STATE_DIR}/terraform.tfstate"

# Local management settings
LOCAL_MANAGEMENT_ENABLED="true"
AUTO_UPDATE_ENABLED="true"
BACKUP_BEFORE_UPDATE="true"

# Logging
LOG_LEVEL="INFO"
LOG_FILE="${LOG_DIR}/management.log"
EOF

    log_success "Environment configuration created"
}

# Function to create management scripts
create_management_scripts() {
    log_info "Creating management scripts..."

    mkdir -p "${REPO_DIR}/scripts"

    # Create update script
    cat > "${REPO_DIR}/scripts/local_update.sh" <<'EOF'
#!/bin/bash

# Local Update Script for Proxmox Server
# Automatically updates configuration from git and applies changes

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
source "${REPO_DIR}/.env"

if [[ -f "${REPO_DIR}/.env.${CURRENT_SITE_NAME}" ]]; then
    source "${REPO_DIR}/.env.${CURRENT_SITE_NAME}"
fi

LOG_FILE="${LOG_FILE:-/var/log/proxmox-firewall/management.log}"

# Logging function
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_msg "=== Starting local update process ==="

cd "$REPO_DIR"

# Check for changes
git fetch origin
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/${GIT_BRANCH:-main})

if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
    log_msg "No updates available"
    exit 0
fi

log_msg "Updates detected: $LOCAL_COMMIT -> $REMOTE_COMMIT"

# Backup current state if enabled
if [[ "${BACKUP_BEFORE_UPDATE:-true}" == "true" ]]; then
    BACKUP_FILE="/opt/proxmox-firewall-backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" -C "$REPO_DIR" . --exclude='.git' --exclude='terraform-state'
    log_msg "Backup created: $BACKUP_FILE"
fi

# Update repository
git reset --hard "origin/${GIT_BRANCH:-main}"
git clean -fd

# Run security audit
if [[ -x "common/scripts/security_audit.sh" ]]; then
    log_msg "Running security audit..."
    if ! ./common/scripts/security_audit.sh | tee -a "$LOG_FILE"; then
        log_msg "WARNING: Security audit found issues"
    fi
fi

# Apply configuration updates
log_msg "Applying configuration updates..."

# Run ansible maintenance playbook
if [[ -f "proxmox-local/ansible/site.yml" ]]; then
    cd proxmox-local/ansible
    if ansible-playbook site.yml --tags maintenance --limit="${CURRENT_SITE_NAME}" 2>&1 | tee -a "$LOG_FILE"; then
        log_msg "Ansible maintenance completed successfully"
    else
        log_msg "ERROR: Ansible maintenance failed"
        exit 1
    fi
    cd "$REPO_DIR"
fi

# Update Terraform if needed
if [[ -d "common/terraform" ]]; then
    cd common/terraform
    if terraform plan -detailed-exitcode -out="/tmp/tfplan.${CURRENT_SITE_NAME}" 2>&1 | tee -a "$LOG_FILE"; then
        PLAN_EXIT_CODE=$?
        if [[ $PLAN_EXIT_CODE -eq 2 ]]; then
            log_msg "Terraform changes detected, applying..."
            if terraform apply "/tmp/tfplan.${CURRENT_SITE_NAME}" 2>&1 | tee -a "$LOG_FILE"; then
                log_msg "Terraform apply completed successfully"
                rm -f "/tmp/tfplan.${CURRENT_SITE_NAME}"
            else
                log_msg "ERROR: Terraform apply failed"
                exit 1
            fi
        elif [[ $PLAN_EXIT_CODE -eq 0 ]]; then
            log_msg "No Terraform changes needed"
        else
            log_msg "ERROR: Terraform plan failed"
            exit 1
        fi
    fi
    cd "$REPO_DIR"
fi

log_msg "=== Local update process completed successfully ==="
EOF

    chmod +x "${REPO_DIR}/scripts/local_update.sh"

    # Create status script
    cat > "${REPO_DIR}/scripts/local_status.sh" <<'EOF'
#!/bin/bash

# Local Status Script for Proxmox Server
# Shows current status of local management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

echo "=== Proxmox Firewall Local Management Status ==="
echo ""

# Git status
echo "📁 Repository Status:"
echo "  Current commit: $(git rev-parse --short HEAD)"
echo "  Branch: $(git branch --show-current)"
echo "  Last update: $(git log -1 --format='%cr (%an)')"
echo ""

# Check for updates
git fetch origin &>/dev/null
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/$(git branch --show-current))

if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo "✅ Repository is up to date"
else
    echo "🔄 Updates available: $(git rev-list --count HEAD..origin/$(git branch --show-current)) commits behind"
fi
echo ""

# Terraform state
if [[ -f "/opt/proxmox-firewall/terraform-state/terraform.tfstate" ]]; then
    echo "🏗️  Terraform State:"
    STATE_SIZE=$(stat -c%s "/opt/proxmox-firewall/terraform-state/terraform.tfstate")
    echo "  State file size: ${STATE_SIZE} bytes"
    RESOURCE_COUNT=$(jq '.resources | length' "/opt/proxmox-firewall/terraform-state/terraform.tfstate" 2>/dev/null || echo "unknown")
    echo "  Managed resources: ${RESOURCE_COUNT}"
else
    echo "⚠️  No Terraform state found"
fi
echo ""

# Recent logs
echo "📋 Recent Activity (last 10 lines):"
if [[ -f "/var/log/proxmox-firewall/management.log" ]]; then
    tail -10 "/var/log/proxmox-firewall/management.log" | sed 's/^/  /'
else
    echo "  No management logs found"
fi
EOF

    chmod +x "${REPO_DIR}/scripts/local_status.sh"

    log_success "Management scripts created"
}

# Function to setup cron jobs
setup_cron() {
    log_info "Setting up cron jobs..."

    # Create cron job for automatic updates
    CRON_CMD="${REPO_DIR}/scripts/local_update.sh"

    # Remove existing cron job if present
    (crontab -u "$CRON_USER" -l 2>/dev/null | grep -v "$CRON_CMD" || true) | crontab -u "$CRON_USER" -

    # Add new cron job
    (crontab -u "$CRON_USER" -l 2>/dev/null || true; echo "$UPDATE_SCHEDULE $CRON_CMD >/dev/null 2>&1") | crontab -u "$CRON_USER" -

    log_success "Cron job configured: $UPDATE_SCHEDULE"

    # Show current cron jobs
    log_info "Current cron jobs for $CRON_USER:"
    crontab -u "$CRON_USER" -l | grep -v '^#' | sed 's/^/  /' || echo "  No cron jobs found"
}

# Function to create systemd service (alternative to cron)
create_systemd_service() {
    log_info "Creating systemd service for updates..."

    # Create service file
    cat > /etc/systemd/system/proxmox-firewall-update.service <<EOF
[Unit]
Description=Proxmox Firewall Configuration Update
After=network.target

[Service]
Type=oneshot
ExecStart=${REPO_DIR}/scripts/local_update.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file
    cat > /etc/systemd/system/proxmox-firewall-update.timer <<EOF
[Unit]
Description=Run Proxmox Firewall Configuration Update
Requires=proxmox-firewall-update.service

[Timer]
OnCalendar=*:0/15  # Every 15 minutes
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable timer
    systemctl daemon-reload
    systemctl enable proxmox-firewall-update.timer
    systemctl start proxmox-firewall-update.timer

    log_success "Systemd service and timer created and enabled"
}

# Main execution
main() {
    log_info "Starting Proxmox Firewall Local Management Setup"

    # Validate environment
    check_proxmox
    validate_params "$@"

    # Setup process
    setup_directories
    install_dependencies
    clone_repository
    setup_terraform_state
    setup_environment
    create_management_scripts

    # Setup automation (choose one)
    if command -v systemctl &> /dev/null; then
        create_systemd_service
    else
        setup_cron
    fi

    log_success "Local management setup completed!"
    echo ""
    echo "=== Next Steps ==="
    echo ""
    echo "1. Configure environment variables:"
    echo "   nano ${REPO_DIR}/.env"
    echo ""
    echo "2. Test the setup:"
    echo "   ${REPO_DIR}/scripts/local_status.sh"
    echo ""
    echo "3. Run initial update:"
    echo "   ${REPO_DIR}/scripts/local_update.sh"
    echo ""
    echo "4. Monitor logs:"
    echo "   tail -f ${LOG_DIR}/management.log"
    echo ""
    echo "The system will now automatically update every 15 minutes."
}

# Run main function with all arguments
main "$@"
