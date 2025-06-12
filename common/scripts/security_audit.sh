#!/bin/bash

# Security Audit Script for Proxmox Firewall Repository
# This script checks for accidentally committed sensitive files and configuration issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo -e "${BLUE}🔒 Proxmox Firewall Security Audit${NC}"
echo "=========================================="
echo

# Function to log different types of messages
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

cd "${REPO_ROOT}"

# Check 1: Verify .gitignore is comprehensive
log_info "Checking .gitignore configuration..."
if [[ -f ".gitignore" ]]; then
    # Check for essential security patterns
    security_patterns=(
        "\.env"
        "\*\.key"
        "\*\.pem"
        "\*\.crt"
        "credentials/"
        "\*secret\*"
        "\*password\*"
        "\*api_key\*"
        "\*api_token\*"
    )

    missing_patterns=()
    for pattern in "${security_patterns[@]}"; do
        if ! grep -q "${pattern}" .gitignore; then
            missing_patterns+=("${pattern}")
        fi
    done

    if [[ ${#missing_patterns[@]} -eq 0 ]]; then
        log_success ".gitignore has comprehensive security patterns"
    else
        log_warning ".gitignore missing some security patterns: ${missing_patterns[*]}"
    fi
else
    log_error ".gitignore file not found!"
fi

# Check 2: Look for committed sensitive files
log_info "Checking for committed sensitive files..."
sensitive_files_found=()

# Check for committed .env files (except .example)
while IFS= read -r -d '' file; do
    if [[ ! "$file" =~ \.example$ ]]; then
        sensitive_files_found+=("$file")
    fi
done < <(git ls-files -z | grep -zE '\.(env|key|pem|crt|pfx|p12|jks)$' || true)

# Check for potential secret patterns in committed files
while IFS= read -r file; do
    if git show "HEAD:$file" 2>/dev/null | grep -qiE '(password|secret|api_key|token).*=.*[^#]' 2>/dev/null; then
        # Skip example/template files
        if [[ ! "$file" =~ \.(example|template|sample)$ ]] && [[ ! "$file" =~ example ]]; then
            sensitive_files_found+=("$file (contains potential secrets)")
        fi
    fi
done < <(git ls-files | grep -E '\.(yml|yaml|toml|conf|cfg|ini|sh|py|js|ts)$' || true)

if [[ ${#sensitive_files_found[@]} -eq 0 ]]; then
    log_success "No sensitive files found in git history"
else
    log_error "Found potentially sensitive files:"
    for file in "${sensitive_files_found[@]}"; do
        echo "  - $file"
    done
fi

# Check 3: Verify local .env file exists and is properly configured
log_info "Checking local environment configuration..."
if [[ -f ".env" ]]; then
    log_warning ".env file exists locally (good for development, but ensure it's not committed)"

    # Check for placeholder values
    placeholder_count=$(grep -c "changeme\|example\|your_\|xxxx\|0000" .env || true)
    if [[ $placeholder_count -gt 0 ]]; then
        log_warning "Found $placeholder_count placeholder values in .env - make sure to update these"
    fi

    # Check for empty critical values
    empty_secrets=$(grep -E "_(SECRET|PASSWORD|KEY|TOKEN)=" .env | grep '=""' | wc -l || true)
    if [[ $empty_secrets -gt 0 ]]; then
        log_warning "Found $empty_secrets empty credential values in .env"
    fi
else
    log_info "No local .env file found (you may need to copy from env.example)"
fi

# Check 4: Verify SSH key configuration
log_info "Checking SSH key configuration..."
if [[ -f ".env" ]]; then
    ssh_key_file=$(grep "ANSIBLE_SSH_PRIVATE_KEY_FILE=" .env | cut -d'"' -f2 | envsubst || echo "")
    if [[ -n "$ssh_key_file" ]]; then
        # Expand ~ to home directory
        ssh_key_file="${ssh_key_file/#\~/$HOME}"
        if [[ -f "$ssh_key_file" ]]; then
            # Check key permissions
            perms=$(stat -c "%a" "$ssh_key_file" 2>/dev/null || echo "")
            if [[ "$perms" == "600" ]]; then
                log_success "SSH private key has correct permissions (600)"
            else
                log_warning "SSH private key should have 600 permissions, currently: $perms"
            fi
        else
            log_warning "SSH private key file not found: $ssh_key_file"
        fi
    fi
fi

# Check 5: Look for sensitive data in configuration files
log_info "Scanning configuration files for potential sensitive data..."
config_files=(
    "config/sites/*.yml"
    "deployment/ansible/group_vars/*.yml"
    "deployment/ansible/host_vars/*.yml"
    "*.tfvars"
)

sensitive_patterns_found=()
for pattern in "${config_files[@]}"; do
    # Use find to handle glob patterns safely
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && ! [[ "$file" =~ \.(example|template|sample)$ ]]; then
            # Look for potential hardcoded secrets
            if grep -qiE '(password|secret|key|token).*:.*['\''"][^#]*['\''"]' "$file" 2>/dev/null; then
                sensitive_patterns_found+=("$file")
            fi
        fi
    done < <(find . -path "./.git" -prune -o -name "${pattern##*/}" -print0 2>/dev/null || true)
done

if [[ ${#sensitive_patterns_found[@]} -eq 0 ]]; then
    log_success "No hardcoded secrets found in configuration files"
else
    log_warning "Found potential hardcoded secrets in:"
    for file in "${sensitive_patterns_found[@]}"; do
        echo "  - $file"
    done
fi

# Check 6: Directory permissions for sensitive areas
log_info "Checking directory permissions..."
sensitive_dirs=("credentials" "keys" "certs" "certificates" "secrets")
for dir in "${sensitive_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        perms=$(stat -c "%a" "$dir" 2>/dev/null || echo "")
        if [[ "$perms" =~ ^7[0-7][0-7]$ ]]; then
            log_success "Directory $dir has secure permissions ($perms)"
        else
            log_warning "Directory $dir should have restrictive permissions, currently: $perms"
        fi
    fi
done

# Check 7: Verify security documentation is up to date
log_info "Checking security documentation..."
security_docs=("SECURITY.md" "docs/TROUBLESHOOTING.md")
for doc in "${security_docs[@]}"; do
    if [[ -f "$doc" ]]; then
        log_success "Security documentation found: $doc"
    else
        log_warning "Missing security documentation: $doc"
    fi
done

echo
echo "=========================================="
log_info "Security audit complete!"
echo
echo -e "${YELLOW}Remember to:${NC}"
echo "• Never commit .env files or secrets"
echo "• Use environment variables for all sensitive data"
echo "• Keep SSH keys with 600 permissions"
echo "• Rotate API tokens regularly"
echo "• Review commits for sensitive data before pushing"
echo
echo -e "${BLUE}For more security information, see SECURITY.md${NC}"
