"""
Firewall API Router for OPNsense Mock
Handles firewall rules and configuration
"""

from fastapi import APIRouter, Depends
from typing import Dict, Any, List
from ..storage import MemoryStorage

router = APIRouter()

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
