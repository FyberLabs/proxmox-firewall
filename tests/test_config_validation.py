#!/usr/bin/env python3
"""
Unit tests for configuration validation.
Fast, lightweight tests that don't require Docker or external services.
"""

import pytest
import yaml
import os
from pathlib import Path


class TestConfigValidation:
    """Test configuration file validation."""

    @pytest.fixture
    def project_root(self):
        """Get the project root directory."""
        return Path(__file__).parent.parent

    @pytest.fixture
    def site_template(self, project_root):
        """Load the site template."""
        template_path = project_root / "config" / "site_template.yml"
        if template_path.exists():
            with open(template_path, 'r') as f:
                return yaml.safe_load(f)
        return None

    def test_site_template_exists(self, project_root):
        """Test that site template exists and is valid YAML."""
        template_path = project_root / "config" / "site_template.yml"
        assert template_path.exists(), "Site template should exist"

        with open(template_path, 'r') as f:
            config = yaml.safe_load(f)

        assert config is not None, "Site template should be valid YAML"
        assert 'site' in config, "Site template should have 'site' key"

    def test_site_template_structure(self, site_template):
        """Test that site template has required structure."""
        if site_template is None:
            pytest.skip("Site template not found")

        site = site_template['site']

        # Required top-level keys
        required_keys = ['name', 'network_prefix', 'domain', 'hardware']
        for key in required_keys:
            assert key in site, f"Site template should have '{key}' key"

        # Hardware section structure
        hardware = site['hardware']
        assert 'cpu' in hardware, "Hardware should have CPU configuration"
        assert 'memory' in hardware, "Hardware should have memory configuration"
        assert 'storage' in hardware, "Hardware should have storage configuration"
        assert 'network' in hardware, "Hardware should have network configuration"

    def test_example_site_config(self, project_root):
        """Test the docker test framework example site config."""
        example_path = project_root / "docker-test-framework" / "example-site.yml"

        if not example_path.exists():
            pytest.skip("Example site config not found")

        with open(example_path, 'r') as f:
            config = yaml.safe_load(f)

        assert config is not None, "Example site config should be valid YAML"
        assert 'site' in config, "Example site should have 'site' key"

        site = config['site']
        assert site['name'] == "example-site", "Example site should have correct name"
        assert site['network_prefix'] == "10.99", "Example site should use test network"

    def test_network_prefix_format(self, site_template):
        """Test that network prefix follows expected format."""
        if site_template is None:
            pytest.skip("Site template not found")

        network_prefix = site_template['site']['network_prefix']

        # Should be in format "10.x" where x is a number
        assert network_prefix.startswith("10."), "Network prefix should start with '10.'"
        parts = network_prefix.split(".")
        assert len(parts) == 2, "Network prefix should have format '10.x'"
        assert parts[1] == "x", "Network prefix should use 'x' as placeholder"

    def test_vlan_configuration(self, site_template):
        """Test VLAN configuration in site template."""
        if site_template is None:
            pytest.skip("Site template not found")

        vlans = site_template['site']['hardware']['network']['vlans']

        # Check for standard VLANs
        vlan_ids = [vlan['id'] for vlan in vlans]
        expected_vlans = [10, 20, 30, 40, 50]  # Main, Cameras, IoT, Guest, Management

        for expected_id in expected_vlans:
            assert expected_id in vlan_ids, f"VLAN {expected_id} should be configured"

        # Check VLAN structure
        for vlan in vlans:
            assert 'id' in vlan, "VLAN should have ID"
            assert 'name' in vlan, "VLAN should have name"
            assert 'subnet' in vlan, "VLAN should have subnet"
            assert 'dhcp' in vlan, "VLAN should have DHCP setting"
            assert 'gateway' in vlan, "VLAN should have gateway"


class TestDeviceTemplates:
    """Test device template validation."""

    @pytest.fixture
    def project_root(self):
        """Get the project root directory."""
        return Path(__file__).parent.parent

    def test_device_templates_directory_exists(self, project_root):
        """Test that device templates directory exists."""
        templates_dir = project_root / "config" / "devices_templates"
        assert templates_dir.exists(), "Device templates directory should exist"
        assert templates_dir.is_dir(), "Device templates should be a directory"

    def test_device_templates_are_valid_yaml(self, project_root):
        """Test that all device templates are valid YAML."""
        templates_dir = project_root / "config" / "devices_templates"

        if not templates_dir.exists():
            pytest.skip("Device templates directory not found")

        # Look for Jinja2 template files (.yml.j2) which are the actual device templates
        yaml_files = list(templates_dir.glob("*.yml.j2")) + list(templates_dir.glob("*.yaml.j2"))

        assert len(yaml_files) > 0, "Should have at least one device template"

        for yaml_file in yaml_files:
            with open(yaml_file, 'r') as f:
                content = f.read()

            # Basic validation that the file contains YAML-like structure
            # We can't parse as YAML directly since these are Jinja2 templates
            assert content.strip(), f"Device template {yaml_file.name} should not be empty"
            assert "type:" in content, f"Device template {yaml_file.name} should contain device type configuration"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
