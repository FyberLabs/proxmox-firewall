"""
Memory Storage for OPNsense Mock
Handles in-memory storage of firewall configuration
"""

from typing import Dict, List, Any, Optional
import time
import uuid
import structlog

logger = structlog.get_logger(__name__)

class MemoryStorage:
    """In-memory storage for mock OPNsense data"""

    def __init__(self):
        self.interfaces: Dict[str, Dict[str, Any]] = {}
        self.vlans: Dict[str, Dict[str, Any]] = {}
        self.firewall_rules: Dict[str, Dict[str, Any]] = {}
        self.nat_rules: Dict[str, Dict[str, Any]] = {}
        self.aliases: Dict[str, Dict[str, Any]] = {}
        self.initialized = False

    async def initialize_defaults(self, settings) -> None:
        """Initialize default data for testing"""
        if self.initialized:
            return

        logger.info("Initializing OPNsense storage with default data")

        # Initialize default interfaces
        for interface_name in settings.interfaces:
            self.interfaces[interface_name] = {
                "name": interface_name,
                "status": "up",
                "type": "physical",
                "ip": f"192.168.{ord(interface_name[0]) - 96}.1" if interface_name != "wan" else "10.0.0.1",
                "subnet": 24,
                "speed": "1000Mbps",
                "duplex": "full"
            }

        # Initialize default VLANs
        for vlan_id in [10, 20, 30, 40, 50]:
            vlan_uuid = str(uuid.uuid4())
            self.vlans[vlan_uuid] = {
                "uuid": vlan_uuid,
                "vlan": vlan_id,
                "interface": "lan",
                "description": f"VLAN{vlan_id}"
            }

        # Initialize default firewall rules
        rule_uuid = str(uuid.uuid4())
        self.firewall_rules[rule_uuid] = {
            "uuid": rule_uuid,
            "type": "pass",
            "interface": "lan",
            "source": "any",
            "destination": "any",
            "protocol": "any",
            "description": "Default LAN to any rule"
        }

        # Initialize default aliases
        alias_uuid = str(uuid.uuid4())
        self.aliases[alias_uuid] = {
            "uuid": alias_uuid,
            "name": "RFC1918_Networks",
            "type": "network",
            "content": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
            "description": "Private network ranges"
        }

        self.initialized = True
        logger.info("OPNsense storage initialization completed")

    async def get_interfaces(self) -> List[Dict[str, Any]]:
        """Get all interfaces"""
        return list(self.interfaces.values())

    async def get_vlans(self) -> List[Dict[str, Any]]:
        """Get all VLANs"""
        return list(self.vlans.values())

    async def create_vlan(self, vlan_data: Dict[str, Any]) -> str:
        """Create a new VLAN"""
        vlan_uuid = str(uuid.uuid4())
        vlan_data["uuid"] = vlan_uuid
        self.vlans[vlan_uuid] = vlan_data
        logger.info("VLAN created", uuid=vlan_uuid, vlan=vlan_data.get("vlan"))
        return vlan_uuid

    async def get_firewall_rules(self) -> List[Dict[str, Any]]:
        """Get all firewall rules"""
        return list(self.firewall_rules.values())

    async def create_firewall_rule(self, rule_data: Dict[str, Any]) -> str:
        """Create a new firewall rule"""
        rule_uuid = str(uuid.uuid4())
        rule_data["uuid"] = rule_uuid
        self.firewall_rules[rule_uuid] = rule_data
        logger.info("Firewall rule created", uuid=rule_uuid)
        return rule_uuid

    async def update_firewall_rule(self, rule_id: str, rule_data: Dict[str, Any]) -> None:
        """Update firewall rule"""
        if rule_id in self.firewall_rules:
            self.firewall_rules[rule_id].update(rule_data)
            logger.info("Firewall rule updated", uuid=rule_id)

    async def delete_firewall_rule(self, rule_id: str) -> None:
        """Delete firewall rule"""
        if rule_id in self.firewall_rules:
            del self.firewall_rules[rule_id]
            logger.info("Firewall rule deleted", uuid=rule_id)

    async def get_nat_rules(self) -> List[Dict[str, Any]]:
        """Get all NAT rules"""
        return list(self.nat_rules.values())

    async def get_aliases(self) -> List[Dict[str, Any]]:
        """Get all aliases"""
        return list(self.aliases.values())
