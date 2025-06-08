"""
Interfaces API Router for OPNsense Mock
Handles network interface configuration
"""

from fastapi import APIRouter, Depends
from typing import Dict, Any
from ..storage import MemoryStorage

router = APIRouter()

@router.get("/overview")
async def get_interfaces_overview(storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """Get interfaces overview"""
    interfaces = await storage.get_interfaces()
    return {"status": "ok", "interfaces": interfaces}

@router.get("/vlan")
async def list_vlans(storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """List VLANs"""
    vlans = await storage.get_vlans()
    return {"status": "ok", "vlans": vlans}

@router.post("/vlan")
async def create_vlan(
    vlan_data: Dict[str, Any],
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Create VLAN"""
    vlan_id = await storage.create_vlan(vlan_data)
    return {"status": "ok", "uuid": vlan_id}
