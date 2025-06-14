#!/usr/bin/env python3
"""
Test Suite for Simplified Configuration Approach
Validates that the single YAML file per site approach works correctly
"""

import os
import sys
import yaml
import tempfile
import subprocess
from pathlib import Path
import unittest

# Refactored: Use PROXMOX_FW_CONFIG_ROOT for config path, supporting submodule usage.
PROXMOX_FW_CONFIG_ROOT = os.environ.get('PROXMOX_FW_CONFIG_ROOT')
if not PROXMOX_FW_CONFIG_ROOT:
    if os.path.isdir('./config'):
        PROXMOX_FW_CONFIG_ROOT = './config'
    else:
        raise RuntimeError('Could not find config root directory.')

class TestSimplifiedConfig(unittest.TestCase):
    """Test the simplified single-YAML configuration approach"""

    def setUp(self):
        self.test_dir = Path(__file__).parent
        self.project_root = self.test_dir.parent
        self.example_config = self.test_dir / "example-site.yml"
        self.site_template = self.project_root / "config" / "site_template.yml"

    def test_example_site_has_complete_structure(self):
        """Test that example site config has all required sections"""
        with open(self.example_config, 'r') as f:
            config = yaml.safe_load(f)

        # Check top-level structure
        self.assertIn('site', config)
        site = config['site']

        # Check all major sections exist
        required_sections = [
            'name', 'display_name', 'network_prefix', 'domain',
            'hardware', 'proxmox', 'vm_templates', 'security', 'credentials'
        ]

        for section in required_sections:
            with self.subTest(section=section):
                self.assertIn(section, site, f"Missing required section: {section}")

        print("✓ Example site config has complete structure")

    def test_site_template_has_complete_structure(self):
        """Test that site template has all required sections"""
        with open(self.site_template, 'r') as f:
            config = yaml.safe_load(f)

        # Check top-level structure
        self.assertIn('site', config)
        site = config['site']

        # Check all major sections exist
        required_sections = [
            'name', 'display_name', 'network_prefix', 'domain',
            'hardware', 'proxmox', 'vm_templates', 'security', 'credentials'
        ]

        for section in required_sections:
            with self.subTest(section=section):
                self.assertIn(section, site, f"Missing required section: {section}")

        print("✓ Site template has complete structure")

    def test_no_duplicate_config_files(self):
        """Test that we don't have duplicate configuration files"""
        # Check that we don't have old site .conf files in test framework
        # (exclude legitimate service config files like logstash.conf)
        conf_files = []
        for conf_file in self.test_dir.glob("**/*.conf"):
            # Skip legitimate service configuration files
            if not any(service in str(conf_file) for service in ['logstash', 'prometheus', 'grafana']):
                # Skip if it's in a configs/ directory (service configs)
                if 'configs/' not in str(conf_file):
                    conf_files.append(conf_file)

        self.assertEqual(len(conf_files), 0, f"Found unexpected site .conf files: {conf_files}")

        # Check that we don't have separate Ansible group vars for test sites
        test_group_vars = self.test_dir / "deployment" / "ansible" / "group_vars"
        if test_group_vars.exists():
            test_site_vars = list(test_group_vars.glob("test-*.yml"))
            self.assertEqual(len(test_site_vars), 0, f"Found unexpected test site group vars: {test_site_vars}")

        print("✓ No duplicate configuration files found")

    def test_credentials_are_environment_variables(self):
        """Test that credentials reference environment variables, not hardcoded values"""
        with open(self.example_config, 'r') as f:
            config = yaml.safe_load(f)

        site = config['site']
        if 'credentials' in site:
            creds = site['credentials']

            for key, value in creds.items():
                with self.subTest(credential=key):
                    self.assertIsInstance(value, str)
                    # Should be uppercase environment variable names or file paths
                    if key.endswith('_secret') or key.endswith('_key'):
                        self.assertTrue(
                            value.isupper() or '_' in value,
                            f"Credential {key} should reference environment variable, got: {value}"
                        )

        print("✓ Credentials properly reference environment variables")

    def test_network_configuration_consistency(self):
        """Test that network configuration is internally consistent"""
        with open(self.example_config, 'r') as f:
            config = yaml.safe_load(f)

        site = config['site']
        network_prefix = site['network_prefix']

        # Check VLAN subnets match network prefix
        if 'hardware' in site and 'network' in site['hardware']:
            vlans = site['hardware']['network'].get('vlans', [])
            for vlan in vlans:
                subnet = vlan.get('subnet', '')
                with self.subTest(vlan_id=vlan.get('id')):
                    self.assertTrue(
                        subnet.startswith(network_prefix),
                        f"VLAN {vlan['id']} subnet {subnet} doesn't match network prefix {network_prefix}"
                    )

        print("✓ Network configuration is internally consistent")

    def test_vm_templates_are_properly_configured(self):
        """Test that VM templates have proper configuration"""
        with open(self.example_config, 'r') as f:
            config = yaml.safe_load(f)

        site = config['site']
        vm_templates = site.get('vm_templates', {})

        # Check that we have the expected VM templates
        expected_vms = ['opnsense', 'tailscale', 'zeek']
        for vm_name in expected_vms:
            with self.subTest(vm=vm_name):
                self.assertIn(vm_name, vm_templates, f"Missing VM template: {vm_name}")

                vm_config = vm_templates[vm_name]
                self.assertIn('enabled', vm_config)
                self.assertIn('cores', vm_config)
                self.assertIn('memory', vm_config)
                self.assertIn('network', vm_config)

        print("✓ VM templates are properly configured")

    def test_site_creation_script_generates_correct_format(self):
        """Test that site creation script generates the correct YAML format"""
        script_path = self.project_root / "deployment" / "scripts" / "create_site_config.sh"

        if not script_path.exists():
            self.skipTest("Site creation script not found")

        # Test script syntax
        result = subprocess.run(['bash', '-n', str(script_path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, f"Script syntax error: {result.stderr}")

        # Check that script creates YAML files in config/sites/
        with open(script_path, 'r') as f:
            script_content = f.read()

        # Should create files in config/sites/ (using variable)
        self.assertIn('CONFIG_DIR=', script_content)
        self.assertIn('config/sites', script_content)
        self.assertIn('.yml', script_content)

        # Should not create .conf files for sites (but may reference service configs)
        # Check that it doesn't create site .conf files
        self.assertNotIn('${site_name}.conf', script_content)

        print("✓ Site creation script generates correct format")

    def test_ansible_can_process_single_yaml(self):
        """Test that Ansible can process the single YAML configuration"""
        # Create a simple test playbook that reads the site config
        test_playbook = """
---
- name: Test single YAML processing
  hosts: localhost
  gather_facts: false
  vars:
    site_config_file: "example-site.yml"
  tasks:
    - name: Read site configuration
      include_vars:
        file: "{{ site_config_file }}"
        name: site_config

    - name: Validate site config structure
      assert:
        that:
          - site_config.site is defined
          - site_config.site.name is defined
          - site_config.site.proxmox is defined
          - site_config.site.vm_templates is defined
        fail_msg: "Site configuration is missing required fields"

    - name: Extract values for Terraform
      set_fact:
        terraform_vars:
          site_name: "{{ site_config.site.name }}"
          network_prefix: "{{ site_config.site.network_prefix }}"
          proxmox_host: "{{ site_config.site.proxmox.host }}"

    - name: Validate extracted values
      assert:
        that:
          - terraform_vars.site_name != ""
          - terraform_vars.network_prefix != ""
          - terraform_vars.proxmox_host != ""
        fail_msg: "Failed to extract required values from site config"
"""

        # Create temporary directory for the test
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_dir_path = Path(temp_dir)

            # Write the test playbook
            playbook_path = temp_dir_path / "test_playbook.yml"
            with open(playbook_path, 'w') as f:
                f.write(test_playbook)

            # Copy the example site config to the same directory
            example_site_src = self.test_dir / "example-site.yml"
            example_site_dest = temp_dir_path / "example-site.yml"
            import shutil
            shutil.copy2(example_site_src, example_site_dest)

            # Test if ansible-playbook is available
            result = subprocess.run(['which', 'ansible-playbook'], capture_output=True)
            if result.returncode != 0:
                self.skipTest("Ansible not available")

            # Run the test playbook from the temporary directory
            result = subprocess.run([
                'ansible-playbook',
                'test_playbook.yml',
                '--connection=local',
                '--inventory=localhost,',
                '--limit=localhost'
            ], cwd=temp_dir_path, capture_output=True, text=True, timeout=30)

            self.assertEqual(result.returncode, 0, f"Ansible processing failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}")
            print("✓ Ansible can process single YAML configuration")

    def test_configuration_migration_path(self):
        """Test that old configuration files are not present"""
        # Check that we don't have old-style configuration files

        # No .conf files in deployment
        deployment_dir = self.project_root / "deployment"
        if deployment_dir.exists():
            conf_files = list(deployment_dir.glob("**/*.conf"))
            self.assertEqual(len(conf_files), 0, f"Found old .conf files: {conf_files}")

        # No duplicate group vars for sites
        group_vars_dir = deployment_dir / "ansible" / "group_vars"
        if group_vars_dir.exists():
            # Should not have site-specific group vars (sites should read YAML directly)
            site_group_vars = [f for f in group_vars_dir.glob("*.yml")
                             if f.stem not in ['all', 'localhost']]
            # Allow some group vars, but warn if there are many
            if len(site_group_vars) > 3:
                print(f"Warning: Found {len(site_group_vars)} group vars files, consider migration")

        print("✓ Configuration migration path is clean")

def run_simplified_config_tests():
    """Run all simplified configuration tests"""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestSimplifiedConfig)

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    return result.wasSuccessful()

if __name__ == '__main__':
    success = run_simplified_config_tests()
    sys.exit(0 if success else 1)
