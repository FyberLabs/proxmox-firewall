#!/bin/bash
# Quick Configuration Validation Script
# Validates site configurations and deployment readiness

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [SITE_NAME]"
    echo ""
    echo "Validates site configuration and deployment readiness"
    echo ""
    echo "Arguments:"
    echo "  SITE_NAME    Name of site to validate (optional, validates all if not specified)"
    echo ""
    echo "Examples:"
    echo "  $0           # Validate all site configurations"
    echo "  $0 mysite    # Validate specific site configuration"
}

validate_yaml_syntax() {
    local file="$1"
    
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
        log_error "YAML syntax error in: $file"
        return 1
    fi
    
    return 0
}

validate_site_structure() {
    local file="$1"
    local site_name="$(basename "$file" .yml)"
    
    log_info "Validating structure of $site_name..."
    
    # Use Python to validate structure
    python3 -c "
import yaml
import sys

try:
    with open('$file', 'r') as f:
        config = yaml.safe_load(f)
    
    # Check top-level structure
    if 'site' not in config:
        print('✗ Missing top-level \"site\" section')
        sys.exit(1)
    
    site = config['site']
    
    # Check required fields
    required_fields = ['name', 'display_name', 'network_prefix', 'domain', 'proxmox']
    for field in required_fields:
        if field not in site:
            print(f'✗ Missing required field: {field}')
            sys.exit(1)
    
    # Check proxmox section
    if 'host' not in site['proxmox']:
        print('✗ Missing proxmox.host')
        sys.exit(1)
    
    # Check network consistency if hardware section exists
    if 'hardware' in site and 'network' in site['hardware']:
        network_prefix = site['network_prefix']
        vlans = site['hardware']['network'].get('vlans', [])
        
        for vlan in vlans:
            subnet = vlan.get('subnet', '')
            if subnet and not subnet.startswith(network_prefix):
                print(f'✗ VLAN {vlan.get(\"id\")} subnet {subnet} doesn\\'t match network prefix {network_prefix}')
                sys.exit(1)
    
    print('✓ Site structure is valid')
    
except Exception as e:
    print(f'✗ Validation error: {e}')
    sys.exit(1)
"
    
    if [[ $? -eq 0 ]]; then
        log_success "Structure validation passed for $site_name"
        return 0
    else
        log_error "Structure validation failed for $site_name"
        return 1
    fi
}

validate_credentials() {
    local file="$1"
    local site_name="$(basename "$file" .yml)"
    
    log_info "Checking credentials configuration for $site_name..."
    
    # Extract credential environment variables
    local cred_vars=()
    if python3 -c "
import yaml
with open('$file', 'r') as f:
    config = yaml.safe_load(f)

site = config.get('site', {})
credentials = site.get('credentials', {})

for key, value in credentials.items():
    if key.endswith('_secret') or key.endswith('_key'):
        if isinstance(value, str) and value.isupper():
            print(value)
" 2>/dev/null; then
        while IFS= read -r var; do
            if [[ -n "$var" ]]; then
                cred_vars+=("$var")
            fi
        done < <(python3 -c "
import yaml
with open('$file', 'r') as f:
    config = yaml.safe_load(f)

site = config.get('site', {})
credentials = site.get('credentials', {})

for key, value in credentials.items():
    if key.endswith('_secret') or key.endswith('_key'):
        if isinstance(value, str) and value.isupper():
            print(value)
")
    fi
    
    # Check if .env file exists and contains the variables
    if [[ -f ".env" ]]; then
        local missing_vars=()
        for var in "${cred_vars[@]}"; do
            if ! grep -q "^${var}=" .env; then
                missing_vars+=("$var")
            fi
        done
        
        if [[ ${#missing_vars[@]} -eq 0 ]]; then
            log_success "All required credentials found in .env for $site_name"
        else
            log_warning "Missing credentials in .env for $site_name: ${missing_vars[*]}"
        fi
    else
        log_warning "No .env file found - credentials will need to be set"
    fi
}

validate_deployment_readiness() {
    log_info "Checking deployment readiness..."
    
    local issues=0
    
    # Check for required tools
    local required_tools=("ansible-playbook" "terraform" "docker")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warning "Missing deployment tool: $tool"
            ((issues++))
        fi
    done
    
    # Check deployment scripts
    if [[ ! -f "deployment/scripts/create_site_config.sh" ]]; then
        log_warning "Site creation script not found"
        ((issues++))
    fi
    
    # Check Ansible playbooks
    if [[ -d "deployment/ansible/playbooks" ]]; then
        local playbook_errors=0
        while IFS= read -r -d '' playbook; do
            if command -v ansible-playbook >/dev/null 2>&1; then
                if ! ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
                    log_error "Ansible syntax error in: $playbook"
                    ((playbook_errors++))
                fi
            fi
        done < <(find deployment/ansible/playbooks -name "*.yml" -print0 2>/dev/null || true)
        
        if [[ $playbook_errors -eq 0 ]]; then
            log_success "Ansible playbooks have valid syntax"
        else
            log_error "Found $playbook_errors Ansible syntax errors"
            ((issues++))
        fi
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "Deployment readiness check passed"
        return 0
    else
        log_warning "Found $issues deployment readiness issues"
        return 1
    fi
}

validate_site() {
    local site_file="$1"
    local site_name="$(basename "$site_file" .yml)"
    
    echo -e "\n${BLUE}=== Validating Site: $site_name ===${NC}"
    
    local errors=0
    
    # YAML syntax
    if ! validate_yaml_syntax "$site_file"; then
        ((errors++))
    else
        log_success "YAML syntax is valid"
    fi
    
    # Site structure
    if ! validate_site_structure "$site_file"; then
        ((errors++))
    fi
    
    # Credentials
    validate_credentials "$site_file"
    
    if [[ $errors -eq 0 ]]; then
        log_success "Site $site_name validation passed"
        return 0
    else
        log_error "Site $site_name validation failed with $errors errors"
        return 1
    fi
}

main() {
    local site_name="${1:-}"
    local total_errors=0
    
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Configuration Validation                       ║"
    echo "║                Proxmox Firewall                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Check Python availability
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python3 is required for validation"
        exit 1
    fi
    
    # Install required Python packages if needed
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_info "Installing required Python packages..."
        pip3 install pyyaml >/dev/null 2>&1 || {
            log_error "Failed to install PyYAML. Please install manually: pip3 install pyyaml"
            exit 1
        }
    fi
    
    if [[ -n "$site_name" ]]; then
        # Validate specific site
        local site_file="config/sites/${site_name}.yml"
        if [[ ! -f "$site_file" ]]; then
            log_error "Site configuration not found: $site_file"
            exit 1
        fi
        
        if ! validate_site "$site_file"; then
            ((total_errors++))
        fi
    else
        # Validate all sites
        if [[ -d "config/sites" ]]; then
            local site_count=0
            while IFS= read -r -d '' site_file; do
                if ! validate_site "$site_file"; then
                    ((total_errors++))
                fi
                ((site_count++))
            done < <(find config/sites -name "*.yml" -print0 2>/dev/null || true)
            
            if [[ $site_count -eq 0 ]]; then
                log_warning "No site configurations found in config/sites/"
            fi
        else
            log_warning "No config/sites directory found"
        fi
        
        # Validate example site in test framework
        if [[ -f "docker-test-framework/example-site.yml" ]]; then
            echo -e "\n${BLUE}=== Validating Example Site ===${NC}"
            if ! validate_site "docker-test-framework/example-site.yml"; then
                ((total_errors++))
            fi
        fi
        
        # Validate site template
        if [[ -f "config/site_template.yml" ]]; then
            echo -e "\n${BLUE}=== Validating Site Template ===${NC}"
            if ! validate_site "config/site_template.yml"; then
                ((total_errors++))
            fi
        fi
    fi
    
    # Check deployment readiness
    echo -e "\n${BLUE}=== Deployment Readiness ===${NC}"
    if ! validate_deployment_readiness; then
        log_warning "Some deployment tools may not be available"
    fi
    
    # Summary
    echo -e "\n${BLUE}=== Validation Summary ===${NC}"
    if [[ $total_errors -eq 0 ]]; then
        log_success "All validations passed! ✓"
        echo -e "\n${GREEN}Your configuration is ready for deployment.${NC}"
        echo -e "Run: ${BLUE}ansible-playbook deployment/ansible/master_playbook.yml --limit=SITE_NAME${NC}"
    else
        log_error "Found $total_errors validation errors"
        echo -e "\n${RED}Please fix the errors before deployment.${NC}"
        exit 1
    fi
}

# Handle help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

main "$@" 