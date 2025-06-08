# Network Prefix Format Guide

## Overview

The `network_prefix` field in site configuration files defines the first two octets of your network addressing scheme.

## Format

- **Template Value**: `"10.x"` (used as placeholder in `site_template.yml`)
- **Actual Values**: Replace `"10.x"` with your actual network prefix

## Examples

| Network Prefix | Resulting Subnets | Use Case |
|----------------|-------------------|----------|
| `"10.1"`       | 10.1.10.0/24, 10.1.20.0/24, etc. | Small office/home |
| `"192.168"`    | 192.168.10.0/24, 192.168.20.0/24, etc. | Home networks |
| `"172.16"`     | 172.16.10.0/24, 172.16.20.0/24, etc. | Enterprise |
| `"10.99"`      | 10.99.10.0/24, 10.99.20.0/24, etc. | Testing (example-site.yml) |

## VLAN Subnet Mapping

With network prefix `"10.1"`, VLANs are mapped as:

- VLAN 10 (main): `10.1.10.0/24` with gateway `10.1.10.1`
- VLAN 20 (cameras): `10.1.20.0/24` with gateway `10.1.20.1`
- VLAN 30 (iot): `10.1.30.0/24` with gateway `10.1.30.1`
- VLAN 40 (guest): `10.1.40.0/24` with gateway `10.1.40.1`
- VLAN 50 (management): `10.1.50.0/24` with gateway `10.1.50.1`

## How to Use

1. **Copy the template**: `cp config/site_template.yml config/sites/mysite.yml`
2. **Replace all instances** of `"10.x"` with your chosen prefix
3. **Update all related IPs** (Proxmox host, firewall rules, etc.)

## Validation

The test suite validates that:
- Network prefix follows the expected `"10.x"` format in the template
- Example configurations use proper format (like `"10.99"` in example-site.yml)

## Common Mistakes

❌ **Wrong**: Mixing different prefixes in the same file
❌ **Wrong**: Using `"10.x"` literally in production configs
❌ **Wrong**: Forgetting to update firewall rules and Proxmox host IPs

✅ **Correct**: Consistent prefix throughout the entire configuration file
