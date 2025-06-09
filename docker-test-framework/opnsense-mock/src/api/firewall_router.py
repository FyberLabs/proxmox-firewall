"""
Firewall API Router for OPNsense Mock
Handles firewall rules and configuration
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from typing import Dict, Any, List
import uuid
import time
from ..storage import MemoryStorage

router = APIRouter()

def verify_auth_token(credentials: HTTPAuthorizationCredentials) -> bool:
    """Verify authentication token for security tests"""
    if not credentials:
        return False
    # Mock authentication - accept "test-key" for testing
    return credentials.credentials == "test-key"

@router.get("/alias")
async def list_aliases(storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """List firewall aliases"""
    aliases = await storage.get_aliases()
    return {"status": "ok", "aliases": aliases}

@router.get("/filter")
async def list_filter_rules(storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """List firewall filter rules"""
    rules = await storage.get_firewall_rules()
    return {"status": "ok", "rules": rules}

@router.post("/filter")
async def create_filter_rule(
    rule_data: Dict[str, Any],
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Create a new firewall filter rule"""
    rule_id = await storage.create_firewall_rule(rule_data)
    return {"status": "ok", "uuid": rule_id}

@router.post("/filter/addRule")
async def add_firewall_rule(
    request_data: Dict[str, Any],
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Add firewall rule - enhanced for security testing"""
    rule = request_data.get("rule", {})

    # Validate required fields for security testing
    required_fields = ["description", "action", "interface", "protocol"]
    for field in required_fields:
        if field not in rule:
            raise HTTPException(
                status_code=400,
                detail=f"Missing required field: {field}"
            )

    # Generate UUID for the rule
    rule_id = str(uuid.uuid4())

    # Enhanced rule with security validation
    enhanced_rule = {
        "id": rule_id,
        "uuid": rule_id,
        "created": int(time.time()),
        "enabled": rule.get("enabled", True),
        **rule
    }

    await storage.create_firewall_rule(enhanced_rule)

    return {
        "status": "ok",
        "uuid": rule_id,
        "message": f"Firewall rule '{rule['description']}' created successfully"
    }

@router.put("/filter/{rule_id}")
async def update_filter_rule(
    rule_id: str,
    rule_data: Dict[str, Any],
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Update firewall filter rule"""
    await storage.update_firewall_rule(rule_id, rule_data)
    return {"status": "ok"}

@router.delete("/filter/{rule_id}")
async def delete_filter_rule(
    rule_id: str,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Delete firewall filter rule"""
    await storage.delete_firewall_rule(rule_id)
    return {"status": "ok"}

@router.get("/nat")
async def list_nat_rules(storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """List NAT rules"""
    rules = await storage.get_nat_rules()
    return {"status": "ok", "rules": rules}

@router.post("/apply")
async def apply_firewall_config() -> Dict[str, Any]:
    """Apply firewall configuration"""
    return {
        "status": "ok",
        "status_msg": "Firewall configuration applied successfully"
    }

# Enhanced security testing endpoints

@router.post("/filter/apply")
async def apply_filter_changes() -> Dict[str, Any]:
    """Apply firewall filter changes"""
    return {
        "status": "ok",
        "message": "Firewall filter changes applied successfully",
        "timestamp": int(time.time())
    }

@router.get("/rules/test-connectivity")
async def test_rule_connectivity(
    source: str,
    destination: str,
    protocol: str = "tcp",
    port: int = 80,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Test network connectivity through firewall rules"""

    # Simulate firewall rule evaluation
    rules = await storage.get_firewall_rules()

    # Basic rule evaluation logic for testing
    result = "blocked"  # Default deny
    matched_rule = None

    for rule in rules:
        if _evaluate_rule_match(rule, source, destination, protocol, port):
            result = "allowed" if rule.get("action") == "pass" else "blocked"
            matched_rule = rule.get("description", "Unknown rule")
            break

    return {
        "status": "ok",
        "result": result,
        "source": source,
        "destination": destination,
        "protocol": protocol,
        "port": port,
        "matched_rule": matched_rule,
        "timestamp": int(time.time())
    }

def _evaluate_rule_match(rule: Dict[str, Any], source: str, dest: str, protocol: str, port: int) -> bool:
    """Simple rule matching logic for testing"""

    # Check protocol
    rule_proto = rule.get("protocol", "any")
    if rule_proto != "any" and rule_proto != protocol:
        return False

    # Check source network (simplified)
    rule_source = rule.get("source", "any")
    if rule_source != "any" and not _ip_in_network(source, rule_source):
        return False

    # Check destination network (simplified)
    rule_dest = rule.get("destination", "any")
    if rule_dest != "any" and not _ip_in_network(dest, rule_dest):
        return False

    # Check port
    rule_port = rule.get("destination_port")
    if rule_port and str(rule_port) != str(port):
        return False

    return True

def _ip_in_network(ip: str, network: str) -> bool:
    """Simple IP network matching for testing"""
    if network == "any":
        return True

    # Simple prefix matching for testing
    if "/" in network:
        network_prefix = network.split("/")[0].rsplit(".", 1)[0]
        ip_prefix = ip.rsplit(".", 1)[0]
        return ip_prefix == network_prefix

    return ip == network
