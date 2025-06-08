#!/usr/bin/env python3
"""
Integration Test Suite for Proxmox Firewall Deployment
Tests the complete pipeline: YAML config → Ansible → Terraform → Mock Infrastructure
"""

import os
import sys
import yaml
import json
import subprocess
import requests
import time
import tempfile
import shutil
from pathlib import Path
from typing import Dict, Any, List, Optional
import unittest
from unittest.mock import patch, MagicMock

# Add project root to path for imports
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

class IntegrationTestSuite(unittest.TestCase):
    """Comprehensive integration tests for the deployment pipeline"""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment once for all tests"""
        cls.test_dir = Path(__file__).parent
        cls.project_root = cls.test_dir.parent
        cls.example_site_config = cls.test_dir / "example-site.yml"
        cls.mock_services_url = "http://localhost:8080"
        cls.test_results_dir = cls.test_dir / "test-results"
        cls.test_results_dir.mkdir(exist_ok=True)
        
        # Ensure mock services are running
        cls._wait_for_mock_services()
    
    @classmethod
    def _wait_for_mock_services(cls, timeout=60):
        """Wait for mock services to be ready"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = requests.get(f"{cls.mock_services_url}/health", timeout=5)
                if response.status_code == 200:
                    print("✓ Mock services are ready")
                    return
            except requests.exceptions.RequestException:
                pass
            time.sleep(2)
        
        raise RuntimeError("Mock services failed to start within timeout")
    
    def setUp(self):
        """Set up for each test"""
        self.test_name = self._testMethodName
        print(f"\n🧪 Running test: {self.test_name}")
    
    def tearDown(self):
        """Clean up after each test"""
        # Save test results
        result_file = self.test_results_dir / f"{self.test_name}.json"
        test_result = {
            "test_name": self.test_name,
            "status": "passed" if not hasattr(self, '_outcome') or self._outcome.success else "failed",
            "timestamp": time.time()
        }
        with open(result_file, 'w') as f:
            json.dump(test_result, f, indent=2)

class TestConfigurationValidation(IntegrationTestSuite):
    """Test configuration file validation and parsing"""
    
    def test_example_site_yaml_syntax(self):
        """Test that example site YAML has valid syntax"""
        with open(self.example_site_config, 'r') as f:
            try:
                config = yaml.safe_load(f)
                self.assertIsInstance(config, dict)
                self.assertIn('site', config)
                print("✓ Example site YAML syntax is valid")
            except yaml.YAMLError as e:
                self.fail(f"YAML syntax error: {e}")
    
    def test_site_config_structure(self):
        """Test that site config has required structure"""
        with open(self.example_site_config, 'r') as f:
            config = yaml.safe_load(f)
        
        site = config['site']
        
        # Required top-level fields
        required_fields = ['name', 'display_name', 'network_prefix', 'domain', 'proxmox', 'vm_templates']
        for field in required_fields:
            self.assertIn(field, site, f"Missing required field: {field}")
        
        # Test proxmox config
        proxmox = site['proxmox']
        self.assertIn('host', proxmox)
        self.assertIn('node_name', proxmox)
        
        # Test VM templates
        vm_templates = site['vm_templates']
        self.assertIn('opnsense', vm_templates)
        self.assertIn('tailscale', vm_templates)
        
        print("✓ Site configuration structure is valid")
    
    def test_network_configuration_consistency(self):
        """Test that network configuration is internally consistent"""
        with open(self.example_site_config, 'r') as f:
            config = yaml.safe_load(f)
        
        site = config['site']
        network_prefix = site['network_prefix']
        
        # Check VLAN subnets match network prefix
        if 'hardware' in site and 'network' in site['hardware']:
            vlans = site['hardware']['network'].get('vlans', [])
            for vlan in vlans:
                subnet = vlan.get('subnet', '')
                self.assertTrue(
                    subnet.startswith(network_prefix),
                    f"VLAN {vlan['id']} subnet {subnet} doesn't match network prefix {network_prefix}"
                )
        
        print("✓ Network configuration is consistent")
    
    def test_credentials_configuration(self):
        """Test that credentials are properly configured"""
        with open(self.example_site_config, 'r') as f:
            config = yaml.safe_load(f)
        
        site = config['site']
        
        if 'credentials' in site:
            creds = site['credentials']
            
            # Check that credential references are environment variable names
            for key, value in creds.items():
                if key.endswith('_secret') or key.endswith('_key'):
                    self.assertIsInstance(value, str)
                    self.assertTrue(value.isupper() or '_' in value)
        
        print("✓ Credentials configuration is valid")

class TestAnsibleIntegration(IntegrationTestSuite):
    """Test Ansible playbook integration with site configs"""
    
    def test_ansible_can_read_site_config(self):
        """Test that Ansible can successfully read and parse site config"""
        # Create a temporary Ansible playbook that reads the site config
        playbook_content = """
---
- name: Test site config reading
  hosts: localhost
  gather_facts: false
  vars:
    site_config_file: "{{ playbook_dir }}/example-site.yml"
  tasks:
    - name: Read site configuration
      include_vars:
        file: "{{ site_config_file }}"
        name: site_data
    
    - name: Validate site data
      assert:
        that:
          - site_data.site is defined
          - site_data.site.name is defined
          - site_data.site.proxmox is defined
        fail_msg: "Site configuration is missing required fields"
    
    - name: Display site info
      debug:
        msg: "Successfully loaded site: {{ site_data.site.name }}"
"""
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
            f.write(playbook_content)
            playbook_path = f.name
        
        try:
            # Run the test playbook
            result = subprocess.run([
                'ansible-playbook',
                playbook_path,
                '--connection=local',
                '-v'
            ], cwd=self.test_dir, capture_output=True, text=True, timeout=30)
            
            self.assertEqual(result.returncode, 0, f"Ansible failed: {result.stderr}")
            print("✓ Ansible can read site configuration")
            
        except subprocess.TimeoutExpired:
            self.fail("Ansible playbook timed out")
        except FileNotFoundError:
            self.skipTest("Ansible not available")
        finally:
            os.unlink(playbook_path)
    
    def test_ansible_environment_variable_generation(self):
        """Test that Ansible can generate proper environment variables for Terraform"""
        # Create a playbook that simulates environment variable generation
        playbook_content = """
---
- name: Test environment variable generation
  hosts: localhost
  gather_facts: false
  vars:
    site_config_file: "{{ playbook_dir }}/example-site.yml"
  tasks:
    - name: Read site configuration
      include_vars:
        file: "{{ site_config_file }}"
        name: site_data
    
    - name: Generate Terraform environment variables
      set_fact:
        terraform_env:
          TF_VAR_site_name: "{{ site_data.site.name }}"
          TF_VAR_network_prefix: "{{ site_data.site.network_prefix }}"
          TF_VAR_proxmox_host: "{{ site_data.site.proxmox.host }}"
          TF_VAR_proxmox_node: "{{ site_data.site.proxmox.node_name }}"
    
    - name: Validate environment variables
      assert:
        that:
          - terraform_env.TF_VAR_site_name is defined
          - terraform_env.TF_VAR_network_prefix is defined
          - terraform_env.TF_VAR_proxmox_host is defined
        fail_msg: "Failed to generate required Terraform environment variables"
    
    - name: Display generated variables
      debug:
        var: terraform_env
"""
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False) as f:
            f.write(playbook_content)
            playbook_path = f.name
        
        try:
            result = subprocess.run([
                'ansible-playbook',
                playbook_path,
                '--connection=local',
                '-v'
            ], cwd=self.test_dir, capture_output=True, text=True, timeout=30)
            
            self.assertEqual(result.returncode, 0, f"Ansible failed: {result.stderr}")
            self.assertIn('TF_VAR_site_name', result.stdout)
            print("✓ Ansible can generate Terraform environment variables")
            
        except subprocess.TimeoutExpired:
            self.fail("Ansible playbook timed out")
        except FileNotFoundError:
            self.skipTest("Ansible not available")
        finally:
            os.unlink(playbook_path)

class TestMockInfrastructure(IntegrationTestSuite):
    """Test mock infrastructure services"""
    
    def test_proxmox_mock_health(self):
        """Test that Proxmox mock service is healthy"""
        try:
            response = requests.get(f"{self.mock_services_url}/api2/json/version", timeout=10)
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertIn('data', data)
            print("✓ Proxmox mock service is healthy")
            
        except requests.exceptions.RequestException as e:
            self.fail(f"Proxmox mock service not accessible: {e}")
    
    def test_opnsense_mock_health(self):
        """Test that OPNsense mock service is healthy"""
        try:
            # OPNsense mock typically runs on a different port
            opnsense_url = "http://localhost:8081"
            response = requests.get(f"{opnsense_url}/api/core/firmware/status", timeout=10)
            # OPNsense might return different status codes, so just check it responds
            self.assertIn(response.status_code, [200, 401, 403])
            print("✓ OPNsense mock service is responding")
            
        except requests.exceptions.RequestException as e:
            self.skipTest(f"OPNsense mock service not available: {e}")
    
    def test_mock_vm_creation(self):
        """Test VM creation through mock Proxmox API"""
        vm_config = {
            "vmid": 999,
            "name": "test-vm",
            "cores": 2,
            "memory": 1024,
            "net0": "virtio,bridge=vmbr0"
        }
        
        try:
            response = requests.post(
                f"{self.mock_services_url}/api2/json/nodes/pve/qemu",
                json=vm_config,
                timeout=10
            )
            
            # Mock should accept the request (might return 200 or 201)
            self.assertIn(response.status_code, [200, 201])
            print("✓ Mock VM creation works")
            
        except requests.exceptions.RequestException as e:
            self.fail(f"Mock VM creation failed: {e}")

class TestEndToEndDeployment(IntegrationTestSuite):
    """Test complete end-to-end deployment simulation"""
    
    def test_site_config_to_deployment(self):
        """Test complete pipeline from site config to mock deployment"""
        # This test simulates the entire deployment process
        
        # 1. Validate site configuration
        with open(self.example_site_config, 'r') as f:
            config = yaml.safe_load(f)
        
        site = config['site']
        self.assertIsInstance(site, dict)
        
        # 2. Simulate Ansible variable extraction
        ansible_vars = {
            'site_name': site['name'],
            'network_prefix': site['network_prefix'],
            'proxmox_host': site['proxmox']['host'],
            'vm_templates': site['vm_templates']
        }
        
        # 3. Simulate Terraform environment variables
        terraform_env = {
            f"TF_VAR_{k}": str(v) for k, v in ansible_vars.items()
            if not isinstance(v, dict)
        }
        
        # 4. Test mock infrastructure calls
        for vm_name, vm_config in site['vm_templates'].items():
            if vm_config.get('enabled', False):
                mock_vm_data = {
                    "vmid": vm_config.get('template_id', 100),
                    "name": f"{site['name']}-{vm_name}",
                    "cores": vm_config.get('cores', 1),
                    "memory": vm_config.get('memory', 512)
                }
                
                try:
                    response = requests.post(
                        f"{self.mock_services_url}/api2/json/nodes/pve/qemu",
                        json=mock_vm_data,
                        timeout=10
                    )
                    self.assertIn(response.status_code, [200, 201])
                except requests.exceptions.RequestException:
                    self.skipTest("Mock infrastructure not available")
        
        print("✓ End-to-end deployment simulation successful")
    
    def test_configuration_validation_pipeline(self):
        """Test the complete configuration validation pipeline"""
        # Test multiple site configurations
        test_configs = [
            {
                'site': {
                    'name': 'test-site-1',
                    'network_prefix': '192.168',
                    'domain': 'test1.local',
                    'proxmox': {'host': '192.168.1.100', 'node_name': 'pve'},
                    'vm_templates': {'opnsense': {'enabled': True}}
                }
            },
            {
                'site': {
                    'name': 'test-site-2',
                    'network_prefix': '10.1',
                    'domain': 'test2.local',
                    'proxmox': {'host': '10.1.1.100', 'node_name': 'pve'},
                    'vm_templates': {'tailscale': {'enabled': True}}
                }
            }
        ]
        
        for i, config in enumerate(test_configs):
            with self.subTest(config=i):
                # Validate structure
                self.assertIn('site', config)
                site = config['site']
                
                # Validate required fields
                required = ['name', 'network_prefix', 'domain', 'proxmox']
                for field in required:
                    self.assertIn(field, site)
                
                # Validate network consistency
                network_prefix = site['network_prefix']
                self.assertRegex(network_prefix, r'^\d+\.\d+$')
        
        print("✓ Configuration validation pipeline works")

class TestCICD(IntegrationTestSuite):
    """Test CI/CD specific scenarios"""
    
    def test_static_example_config_validation(self):
        """Test validation of static example config for CI/CD"""
        # This test ensures our example config is always valid for CI/CD
        with open(self.example_site_config, 'r') as f:
            config = yaml.safe_load(f)
        
        # Validate it's a complete, valid configuration
        site = config['site']
        
        # Check all major sections exist
        major_sections = [
            'name', 'display_name', 'network_prefix', 'domain',
            'hardware', 'proxmox', 'vm_templates', 'security'
        ]
        
        for section in major_sections:
            self.assertIn(section, site, f"Missing section: {section}")
        
        # Validate hardware section
        hardware = site['hardware']
        self.assertIn('cpu', hardware)
        self.assertIn('memory', hardware)
        self.assertIn('storage', hardware)
        self.assertIn('network', hardware)
        
        # Validate network section
        network = hardware['network']
        self.assertIn('interfaces', network)
        self.assertIn('vlans', network)
        self.assertIn('bridges', network)
        
        print("✓ Static example config is valid for CI/CD")
    
    def test_deployment_script_syntax(self):
        """Test that deployment scripts have valid syntax"""
        script_path = self.project_root / "deployment" / "scripts" / "create_site_config.sh"
        
        if script_path.exists():
            # Test bash syntax
            result = subprocess.run([
                'bash', '-n', str(script_path)
            ], capture_output=True, text=True)
            
            self.assertEqual(result.returncode, 0, f"Script syntax error: {result.stderr}")
            print("✓ Deployment script syntax is valid")
        else:
            self.skipTest("Deployment script not found")
    
    def test_docker_compose_validation(self):
        """Test that Docker Compose configuration is valid"""
        compose_files = list(self.test_dir.glob("**/docker-compose*.yml"))
        
        for compose_file in compose_files:
            with self.subTest(file=compose_file.name):
                try:
                    result = subprocess.run([
                        'docker-compose', '-f', str(compose_file), 'config'
                    ], capture_output=True, text=True, timeout=30)
                    
                    self.assertEqual(result.returncode, 0, 
                                   f"Docker Compose validation failed for {compose_file}: {result.stderr}")
                except subprocess.TimeoutExpired:
                    self.fail(f"Docker Compose validation timed out for {compose_file}")
                except FileNotFoundError:
                    self.skipTest("Docker Compose not available")
        
        print("✓ Docker Compose configurations are valid")

def run_integration_tests():
    """Run all integration tests"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    test_classes = [
        TestConfigurationValidation,
        TestAnsibleIntegration,
        TestMockInfrastructure,
        TestEndToEndDeployment,
        TestCICD
    ]
    
    for test_class in test_classes:
        tests = loader.loadTestsFromTestCase(test_class)
        suite.addTests(tests)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Return success/failure
    return result.wasSuccessful()

if __name__ == '__main__':
    success = run_integration_tests()
    sys.exit(0 if success else 1) 