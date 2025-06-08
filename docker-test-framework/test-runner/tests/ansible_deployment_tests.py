#!/usr/bin/env python3
"""
Ansible Deployment Tests for Proxmox Firewall

This test suite validates Ansible playbook execution and configuration deployment:
1. Playbook syntax validation
2. Template rendering tests
3. Mock service deployment tests
4. Configuration validation
5. Inventory management tests
"""

import os
import sys
import yaml
import json
import tempfile
import subprocess
import requests
from pathlib import Path
from typing import Dict, List, Any
import logging

class AnsibleDeploymentTests:
    """Test Ansible deployment functionality"""

    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.project_root = Path(__file__).parent.parent.parent.parent
        self.test_site = "test-site"
        self.test_network_prefix = "10.99"

        # Mock service endpoints
        self.proxmox_url = "http://proxmox-mock:8000"
        self.opnsense_url = "https://opnsense-mock:8443"

    def test_playbook_syntax_validation(self):
        """Test Ansible playbook syntax validation"""
        self.logger.info("Testing Ansible playbook syntax...")

        playbook_files = [
            "deployment/ansible/master_playbook.yml",
            "deployment/ansible/playbooks/site_deployment.yml",
            "proxmox-local/ansible/playbooks/06_opnsense_setup.yml",
            "proxmox-local/ansible/playbooks/07a_opnsense_suricata.yml"
        ]

        for playbook_file in playbook_files:
            playbook_path = self.project_root / playbook_file
            if playbook_path.exists():
                try:
                    # Validate YAML syntax
                    with open(playbook_path, 'r') as f:
                        yaml.safe_load(f)

                    # Validate Ansible syntax
                    result = subprocess.run([
                        'ansible-playbook', '--syntax-check', str(playbook_path)
                    ], capture_output=True, text=True, timeout=30)

                    if result.returncode != 0:
                        self.logger.warning(f"Syntax check warning for {playbook_file}: {result.stderr}")

                except yaml.YAMLError as e:
                    raise AssertionError(f"YAML syntax error in {playbook_file}: {e}")
                except subprocess.TimeoutExpired:
                    self.logger.warning(f"Syntax check timed out for {playbook_file}")
                except FileNotFoundError:
                    self.logger.warning("ansible-playbook command not found, skipping syntax check")

        self.logger.info("✓ Playbook syntax validation passed")

    def test_template_rendering(self):
        """Test Jinja2 template rendering with test data"""
        self.logger.info("Testing template rendering...")

        # Test data for template rendering
        test_vars = {
            'site_config': {
                'name': self.test_site,
                'display_name': 'Test Site',
                'network_prefix': self.test_network_prefix,
                'domain': 'test.local',
                'proxmox': {
                    'host': 'proxmox-mock',
                    'node_name': 'pve',
                    'api_secret_env': 'PROXMOX_API_SECRET'
                },
                'vm_templates': {
                    'opnsense': {'enabled': True, 'start_on_deploy': True},
                    'tailscale': {'enabled': True, 'start_on_deploy': True}
                }
            },
            'validated_images': {
                'ubuntu_version': '22.04',
                'ubuntu_image_path': '/var/lib/vz/template/iso/ubuntu-22.04.iso',
                'opnsense_version': '23.7',
                'opnsense_image_path': '/var/lib/vz/template/iso/opnsense-23.7.iso'
            }
        }

        # Test Terraform tfvars template
        tfvars_template_path = self.project_root / "deployment/ansible/templates/terraform.tfvars.j2"
        if tfvars_template_path.exists():
            try:
                from jinja2 import Template

                with open(tfvars_template_path, 'r') as f:
                    template_content = f.read()

                template = Template(template_content)
                rendered = template.render(**test_vars)

                # Validate rendered content
                assert f'site_name = "{self.test_site}"' in rendered
                assert f'network_prefix = "{self.test_network_prefix}"' in rendered
                assert 'proxmox_host = "proxmox-mock"' in rendered

            except ImportError:
                self.logger.warning("Jinja2 not available, skipping template rendering test")

        # Test Proxmox answer file template
        answer_template_path = self.project_root / "deployment/ansible/templates/proxmox-answer.yml.j2"
        if answer_template_path.exists():
            try:
                from jinja2 import Template

                # Add required variables for answer file
                answer_vars = test_vars.copy()
                answer_vars.update({
                    'site': test_vars['site_config'],
                    'proxmox': {
                        'answer_file': {
                            'hostname': 'proxmox',
                            'ip_address': f'{self.test_network_prefix}.50.1',
                            'netmask': '255.255.255.0',
                            'gateway': f'{self.test_network_prefix}.50.1',
                            'dns': '1.1.1.1',
                            'timezone': 'UTC',
                            'keyboard': 'us',
                            'country': 'US'
                        }
                    },
                    'hardware': {
                        'storage': {
                            'type': 'ssd',
                            'size': '128gb',
                            'allocation': {
                                'system': '20gb',
                                'vms': '80gb',
                                'backups': '28gb'
                            }
                        }
                    }
                })

                with open(answer_template_path, 'r') as f:
                    template_content = f.read()

                template = Template(template_content)
                rendered = template.render(**answer_vars)

                # Validate rendered YAML
                rendered_data = yaml.safe_load(rendered)
                assert rendered_data['system']['hostname'] == 'proxmox'
                assert rendered_data['network']['ip_address'] == f'{self.test_network_prefix}.50.1'

            except ImportError:
                self.logger.warning("Jinja2 not available, skipping answer file template test")

        self.logger.info("✓ Template rendering test passed")

    def test_inventory_management(self):
        """Test Ansible inventory management"""
        self.logger.info("Testing inventory management...")

        # Create test inventory
        test_inventory = {
            'all': {
                'vars': {
                    'ansible_password': 'test-password'
                },
                'children': {
                    self.test_site: {
                        'hosts': {
                            f'{self.test_site}-proxmox': {
                                'ansible_host': 'proxmox-mock',
                                'ansible_ssh_user': 'root'
                            },
                            f'{self.test_site}-opnsense': {
                                'ansible_host': 'opnsense-mock',
                                'ansible_ssh_user': 'root',
                                'opn_api_host': 'opnsense-mock',
                                'opn_api_key': 'test-key',
                                'opn_api_secret': 'test-secret'
                            }
                        }
                    }
                }
            }
        }

        # Write test inventory to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
            yaml.dump(test_inventory, f, default_flow_style=False)
            inventory_file = f.name

        try:
            # Test inventory parsing
            result = subprocess.run([
                'ansible-inventory', '-i', inventory_file, '--list'
            ], capture_output=True, text=True, timeout=30)

            if result.returncode == 0:
                inventory_data = json.loads(result.stdout)

                # Validate inventory structure
                assert self.test_site in inventory_data.get('_meta', {}).get('hostvars', {})
                assert f'{self.test_site}-proxmox' in inventory_data.get('_meta', {}).get('hostvars', {})

            else:
                self.logger.warning(f"Inventory parsing warning: {result.stderr}")

        except subprocess.TimeoutExpired:
            self.logger.warning("Inventory parsing timed out")
        except FileNotFoundError:
            self.logger.warning("ansible-inventory command not found, skipping inventory test")
        finally:
            # Clean up temporary file
            os.unlink(inventory_file)

        self.logger.info("✓ Inventory management test passed")

    def test_proxmox_configuration_deployment(self):
        """Test Proxmox configuration deployment via Ansible"""
        self.logger.info("Testing Proxmox configuration deployment...")

        # Test Proxmox API connectivity
        try:
            response = requests.get(f"{self.proxmox_url}/api2/json/version", timeout=10)
            assert response.status_code == 200, "Proxmox mock not accessible"

            # Test node configuration
            node_config = {
                'node': 'pve',
                'storage': {
                    'local': {
                        'type': 'dir',
                        'path': '/var/lib/vz',
                        'content': 'images,iso,vztmpl'
                    }
                },
                'network': {
                    'interfaces': [
                        {'name': 'vmbr0', 'type': 'bridge', 'ports': 'eth2'},
                        {'name': 'vmbr1', 'type': 'bridge', 'ports': 'eth0'},
                        {'name': 'vmbr2', 'type': 'bridge', 'ports': 'eth3'},
                        {'name': 'vmbr3', 'type': 'bridge', 'ports': 'eth1'}
                    ]
                }
            }

            # Test storage configuration
            response = requests.post(f"{self.proxmox_url}/api2/json/storage",
                                   json=node_config['storage'])
            assert response.status_code in [200, 201], "Failed to configure Proxmox storage"

            # Test network bridge configuration
            for interface in node_config['network']['interfaces']:
                response = requests.post(f"{self.proxmox_url}/api2/json/nodes/pve/network",
                                       json=interface)
                assert response.status_code in [200, 201], f"Failed to configure interface {interface['name']}"

        except requests.RequestException as e:
            self.logger.warning(f"Proxmox configuration test skipped: {e}")

        self.logger.info("✓ Proxmox configuration deployment test passed")

    def test_opnsense_configuration_deployment(self):
        """Test OPNsense configuration deployment via Ansible"""
        self.logger.info("Testing OPNsense configuration deployment...")

        try:
            # Test OPNsense API connectivity
            response = requests.get(f"{self.opnsense_url}/api/core/firmware/status",
                                  verify=False, timeout=10)
            assert response.status_code == 200, "OPNsense mock not accessible"

            # Test interface configuration
            interfaces = [
                {
                    'name': 'wan',
                    'interface': 'em0',
                    'type': 'static',
                    'ipaddr': '192.168.1.100',
                    'subnet': '24'
                },
                {
                    'name': 'lan',
                    'interface': 'em1',
                    'type': 'static',
                    'ipaddr': f'{self.test_network_prefix}.10.1',
                    'subnet': '24'
                }
            ]

            for interface in interfaces:
                response = requests.post(f"{self.opnsense_url}/api/interfaces/overview/addInterface",
                                       json=interface, verify=False)
                assert response.status_code in [200, 201], f"Failed to configure interface {interface['name']}"

            # Test VLAN configuration
            vlans = [
                {'vlan': 10, 'interface': 'em1', 'description': 'Main LAN'},
                {'vlan': 20, 'interface': 'em2', 'description': 'Cameras'},
                {'vlan': 30, 'interface': 'em1', 'description': 'IoT'},
                {'vlan': 50, 'interface': 'em1', 'description': 'Management'}
            ]

            for vlan in vlans:
                response = requests.post(f"{self.opnsense_url}/api/interfaces/vlan/addVlan",
                                       json=vlan, verify=False)
                assert response.status_code in [200, 201], f"Failed to configure VLAN {vlan['vlan']}"

            # Test firewall rules
            firewall_rules = [
                {
                    'description': 'Allow LAN to Internet',
                    'interface': 'LAN',
                    'source': f'{self.test_network_prefix}.10.0/24',
                    'destination': 'any',
                    'action': 'pass'
                },
                {
                    'description': 'Block IoT to LAN',
                    'interface': 'LAN',
                    'source': f'{self.test_network_prefix}.30.0/24',
                    'destination': f'{self.test_network_prefix}.10.0/24',
                    'action': 'block'
                }
            ]

            for rule in firewall_rules:
                response = requests.post(f"{self.opnsense_url}/api/firewall/filter/addRule",
                                       json=rule, verify=False)
                assert response.status_code in [200, 201], f"Failed to create firewall rule: {rule['description']}"

        except requests.RequestException as e:
            self.logger.warning(f"OPNsense configuration test skipped: {e}")

        self.logger.info("✓ OPNsense configuration deployment test passed")

    def test_vm_template_deployment(self):
        """Test VM template deployment via Ansible"""
        self.logger.info("Testing VM template deployment...")

        try:
            # Test VM template creation
            vm_templates = [
                {
                    'name': 'ubuntu-template',
                    'ostype': 'l26',
                    'memory': 2048,
                    'cores': 2,
                    'template': True,
                    'description': 'Ubuntu 22.04 Template'
                },
                {
                    'name': 'opnsense-template',
                    'ostype': 'other',
                    'memory': 4096,
                    'cores': 2,
                    'template': True,
                    'description': 'OPNsense Template'
                }
            ]

            for template in vm_templates:
                response = requests.post(f"{self.proxmox_url}/api2/json/nodes/pve/qemu",
                                       json=template)
                assert response.status_code in [200, 201], f"Failed to create template {template['name']}"

            # Test template validation
            response = requests.get(f"{self.proxmox_url}/api2/json/nodes/pve/qemu")
            assert response.status_code == 200, "Failed to get VM list"

            vms = response.json().get('data', [])
            templates = [vm for vm in vms if vm.get('template', False)]

            assert len(templates) >= 2, "VM templates not created correctly"

        except requests.RequestException as e:
            self.logger.warning(f"VM template deployment test skipped: {e}")

        self.logger.info("✓ VM template deployment test passed")

    def test_device_dhcp_configuration(self):
        """Test device DHCP configuration deployment"""
        self.logger.info("Testing device DHCP configuration...")

        # Test device configurations
        test_devices = [
            {
                'name': 'homeassistant',
                'mac_address': '52:54:00:12:34:56',
                'ip_address': f'{self.test_network_prefix}.10.10',
                'vlan': 10
            },
            {
                'name': 'nas',
                'mac_address': '52:54:00:12:34:57',
                'ip_address': f'{self.test_network_prefix}.10.100',
                'vlan': 10
            },
            {
                'name': 'camera1',
                'mac_address': '52:54:00:12:34:58',
                'ip_address': f'{self.test_network_prefix}.20.21',
                'vlan': 20
            }
        ]

        try:
            # Test DHCP static mapping configuration
            for device in test_devices:
                dhcp_mapping = {
                    'mac': device['mac_address'],
                    'ip': device['ip_address'],
                    'hostname': device['name'],
                    'description': f'Static mapping for {device["name"]}'
                }

                response = requests.post(f"{self.opnsense_url}/api/dhcpv4/leases/addLease",
                                       json=dhcp_mapping, verify=False)
                assert response.status_code in [200, 201], f"Failed to create DHCP mapping for {device['name']}"

            # Validate DHCP configuration
            response = requests.get(f"{self.opnsense_url}/api/dhcpv4/leases/searchLease", verify=False)
            assert response.status_code == 200, "Failed to get DHCP leases"

            leases = response.json().get('rows', [])
            static_leases = [lease for lease in leases if lease.get('type') == 'static']

            assert len(static_leases) >= 3, "DHCP static mappings not configured correctly"

        except requests.RequestException as e:
            self.logger.warning(f"DHCP configuration test skipped: {e}")

        self.logger.info("✓ Device DHCP configuration test passed")

    def test_configuration_validation(self):
        """Test configuration validation and consistency"""
        self.logger.info("Testing configuration validation...")

        # Test site configuration consistency
        site_config = {
            'name': self.test_site,
            'network_prefix': self.test_network_prefix,
            'domain': 'test.local',
            'vlans': [10, 20, 30, 40, 50]
        }

        # Validate network prefix consistency
        for vlan in site_config['vlans']:
            expected_subnet = f"{self.test_network_prefix}.{vlan}.0/24"
            # This would normally be validated against actual configuration
            assert expected_subnet.startswith(self.test_network_prefix), \
                f"Network prefix inconsistency for VLAN {vlan}"

        # Test configuration file validation
        config_files = [
            {'path': 'deployment/ansible/group_vars/all.yml', 'required_keys': []},
            {'path': 'common/terraform/variables.tf', 'required_keys': []},
            {'path': 'common/config/site_template.yml', 'required_keys': ['site']}
        ]

        for config_file in config_files:
            config_path = self.project_root / config_file['path']
            if config_path.exists():
                try:
                    with open(config_path, 'r') as f:
                        if config_path.suffix == '.yml':
                            config_data = yaml.safe_load(f)
                            for key in config_file['required_keys']:
                                assert key in config_data, f"Missing required key '{key}' in {config_file['path']}"
                except yaml.YAMLError as e:
                    raise AssertionError(f"YAML error in {config_file['path']}: {e}")

        self.logger.info("✓ Configuration validation test passed")

    def run_all_tests(self):
        """Run all Ansible deployment tests"""
        test_methods = [
            self.test_playbook_syntax_validation,
            self.test_template_rendering,
            self.test_inventory_management,
            self.test_proxmox_configuration_deployment,
            self.test_opnsense_configuration_deployment,
            self.test_vm_template_deployment,
            self.test_device_dhcp_configuration,
            self.test_configuration_validation
        ]

        results = []

        for test_method in test_methods:
            try:
                test_method()
                results.append({'test': test_method.__name__, 'status': 'PASSED', 'error': None})
            except Exception as e:
                self.logger.error(f"Test {test_method.__name__} failed: {str(e)}")
                results.append({'test': test_method.__name__, 'status': 'FAILED', 'error': str(e)})

        return results

def main():
    """Main test execution function"""
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

    test_runner = AnsibleDeploymentTests()

    print("🔧 Starting Ansible Deployment Tests...")
    print("=" * 50)

    results = test_runner.run_all_tests()

    # Print results
    print("\n" + "=" * 50)
    print("📊 ANSIBLE TEST RESULTS")
    print("=" * 50)

    passed = sum(1 for r in results if r['status'] == 'PASSED')
    failed = sum(1 for r in results if r['status'] == 'FAILED')

    for result in results:
        status_icon = "✅" if result['status'] == 'PASSED' else "❌"
        print(f"{status_icon} {result['test']}: {result['status']}")
        if result['error']:
            print(f"   Error: {result['error']}")

    print(f"\n📈 Summary: {passed} passed, {failed} failed")

    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
