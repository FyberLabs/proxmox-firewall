#!/usr/bin/env python3
"""
Test Runner for Docker Testing Framework
Executes test suites for Proxmox firewall deployment
"""

import os
import sys
import json
import time
import subprocess
from typing import Dict, Any, List
import requests
import structlog

# Configure logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)

class TestRunner:
    def __init__(self):
        self.test_suite = os.getenv("TEST_SUITE", "all")
        self.parallel = os.getenv("TEST_PARALLEL", "true").lower() == "true"
        self.debug = os.getenv("TEST_DEBUG", "false").lower() == "true"
        self.proxmox_host = os.getenv("PROXMOX_MOCK_HOST", "proxmox-mock")
        self.proxmox_port = os.getenv("PROXMOX_MOCK_PORT", "8006")
        self.opnsense_host = os.getenv("OPNSENSE_MOCK_HOST", "opnsense-mock")
        self.opnsense_port = os.getenv("OPNSENSE_MOCK_PORT", "443")

        self.results = {
            "start_time": time.time(),
            "test_suite": self.test_suite,
            "parallel": self.parallel,
            "tests": {},
            "summary": {}
        }

    def check_service_health(self, service_name: str, url: str) -> bool:
        """Check if a service is healthy"""
        try:
            if "https" in url:
                response = requests.get(url, verify=False, timeout=10)
            else:
                response = requests.get(url, timeout=10)

            if response.status_code == 200:
                logger.info(f"{service_name} is healthy")
                return True
            else:
                logger.warning(f"{service_name} returned status {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Failed to check {service_name} health", error=str(e))
            return False

    def wait_for_services(self) -> bool:
        """Wait for all required services to be ready"""
        logger.info("Waiting for services to be ready...")

        services = [
            ("Proxmox Mock", f"http://{self.proxmox_host}:{self.proxmox_port}/health"),
            ("OPNsense Mock", f"https://{self.opnsense_host}:{self.opnsense_port}/health")
        ]

        max_retries = 30
        retry_interval = 2

        for service_name, url in services:
            for attempt in range(max_retries):
                if self.check_service_health(service_name, url):
                    break

                if attempt < max_retries - 1:
                    logger.info(f"Waiting for {service_name}... (attempt {attempt + 1}/{max_retries})")
                    time.sleep(retry_interval)
                else:
                    logger.error(f"{service_name} is not responding after {max_retries} attempts")
                    return False

        logger.info("All services are ready")
        return True

    def run_test_suite(self, suite_name: str) -> Dict[str, Any]:
        """Run a specific test suite"""
        logger.info(f"Running test suite: {suite_name}")

        start_time = time.time()

        # Simulate test execution - replace with actual test logic
        if suite_name == "network":
            success = self.test_network_configuration()
        elif suite_name == "firewall":
            success = self.test_firewall_configuration()
        elif suite_name == "vm-deployment":
            success = self.test_vm_deployment()
        elif suite_name == "integration":
            success = self.test_integration()
        elif suite_name == "performance":
            success = self.test_performance()
        else:
            logger.warning(f"Unknown test suite: {suite_name}")
            success = False

        end_time = time.time()
        duration = end_time - start_time

        result = {
            "suite": suite_name,
            "success": success,
            "duration": duration,
            "start_time": start_time,
            "end_time": end_time
        }

        logger.info(f"Test suite {suite_name} completed",
                   success=success, duration=f"{duration:.2f}s")

        return result

    def test_network_configuration(self) -> bool:
        """Test network configuration"""
        logger.info("Testing network configuration...")

        # Test Proxmox API connectivity
        try:
            response = requests.get(f"http://{self.proxmox_host}:{self.proxmox_port}/api2/json/version")
            if response.status_code != 200:
                logger.error("Failed to connect to Proxmox API")
                return False
        except Exception as e:
            logger.error("Network connectivity test failed", error=str(e))
            return False

        # Test OPNsense API connectivity
        try:
            response = requests.get(f"https://{self.opnsense_host}:{self.opnsense_port}/api/core/firmware/status", verify=False)
            if response.status_code != 200:
                logger.error("Failed to connect to OPNsense API")
                return False
        except Exception as e:
            logger.error("OPNsense connectivity test failed", error=str(e))
            return False

        logger.info("Network configuration tests passed")
        return True

    def test_firewall_configuration(self) -> bool:
        """Test firewall configuration"""
        logger.info("Testing firewall configuration...")

        try:
            # Test firewall rules API
            response = requests.get(f"https://{self.opnsense_host}:{self.opnsense_port}/api/firewall/filter", verify=False)
            if response.status_code != 200:
                logger.error("Failed to retrieve firewall rules")
                return False

            # Test VLAN configuration
            response = requests.get(f"https://{self.opnsense_host}:{self.opnsense_port}/api/interfaces/vlan", verify=False)
            if response.status_code != 200:
                logger.error("Failed to retrieve VLAN configuration")
                return False

        except Exception as e:
            logger.error("Firewall configuration test failed", error=str(e))
            return False

        logger.info("Firewall configuration tests passed")
        return True

    def test_vm_deployment(self) -> bool:
        """Test VM deployment"""
        logger.info("Testing VM deployment...")

        try:
            # Test VM listing
            response = requests.get(f"http://{self.proxmox_host}:{self.proxmox_port}/api2/json/nodes/pve/qemu")
            if response.status_code != 200:
                logger.error("Failed to list VMs")
                return False

            # Test storage listing
            response = requests.get(f"http://{self.proxmox_host}:{self.proxmox_port}/api2/json/storage")
            if response.status_code != 200:
                logger.error("Failed to list storage")
                return False

        except Exception as e:
            logger.error("VM deployment test failed", error=str(e))
            return False

        logger.info("VM deployment tests passed")
        return True

    def test_integration(self) -> bool:
        """Test end-to-end integration"""
        logger.info("Testing end-to-end integration...")

        # Run all individual test suites
        network_success = self.test_network_configuration()
        firewall_success = self.test_firewall_configuration()
        vm_success = self.test_vm_deployment()

        success = network_success and firewall_success and vm_success

        if success:
            logger.info("Integration tests passed")
        else:
            logger.error("Integration tests failed")

        return success

    def test_performance(self) -> bool:
        """Test performance"""
        logger.info("Testing performance...")

        # Simple performance test - measure API response times
        try:
            start_time = time.time()
            for _ in range(10):
                requests.get(f"http://{self.proxmox_host}:{self.proxmox_port}/api2/json/version")
            end_time = time.time()

            avg_response_time = (end_time - start_time) / 10
            logger.info(f"Average API response time: {avg_response_time:.3f}s")

            # Consider test passed if average response time is under 1 second
            success = avg_response_time < 1.0

        except Exception as e:
            logger.error("Performance test failed", error=str(e))
            success = False

        if success:
            logger.info("Performance tests passed")
        else:
            logger.error("Performance tests failed")

        return success

    def run(self) -> int:
        """Run the test suite(s)"""
        logger.info("Starting test execution",
                   suite=self.test_suite,
                   parallel=self.parallel)

        # Wait for services to be ready
        if not self.wait_for_services():
            logger.error("Services are not ready, aborting tests")
            return 1

        # Determine which test suites to run
        if self.test_suite == "all":
            suites = ["network", "firewall", "vm-deployment", "integration"]
        else:
            suites = [self.test_suite]

        # Run test suites
        all_success = True
        for suite in suites:
            result = self.run_test_suite(suite)
            self.results["tests"][suite] = result

            if not result["success"]:
                all_success = False

        # Generate summary
        self.results["end_time"] = time.time()
        self.results["total_duration"] = self.results["end_time"] - self.results["start_time"]
        self.results["summary"] = {
            "total_suites": len(suites),
            "passed": sum(1 for r in self.results["tests"].values() if r["success"]),
            "failed": sum(1 for r in self.results["tests"].values() if not r["success"]),
            "success": all_success
        }

        # Save results
        self.save_results()

        # Print summary
        logger.info("Test execution completed",
                   total_duration=f"{self.results['total_duration']:.2f}s",
                   passed=self.results["summary"]["passed"],
                   failed=self.results["summary"]["failed"],
                   success=all_success)

        return 0 if all_success else 1

    def save_results(self):
        """Save test results to file"""
        try:
            os.makedirs("/reports", exist_ok=True)

            timestamp = time.strftime("%Y%m%d_%H%M%S", time.localtime(self.results["start_time"]))
            filename = f"/reports/test_results_{timestamp}.json"

            with open(filename, 'w') as f:
                json.dump(self.results, f, indent=2)

            logger.info(f"Test results saved to {filename}")

        except Exception as e:
            logger.error("Failed to save test results", error=str(e))

def main():
    """Main entry point"""
    runner = TestRunner()
    exit_code = runner.run()
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
