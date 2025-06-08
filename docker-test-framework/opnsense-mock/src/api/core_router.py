"""
Core API Router for OPNsense Mock
Handles core system endpoints
"""

from fastapi import APIRouter
from typing import Dict, Any
import time

router = APIRouter()

@router.get("/firmware/status")
async def get_firmware_status() -> Dict[str, Any]:
    """Get firmware status"""
    return {
        "status": "ok",
        "status_msg": "Firmware is up to date",
        "last_check": int(time.time()),
        "updates": 0,
        "upgrade_needs_reboot": False,
        "connection": "ok",
        "repository": "OPNsense",
        "product": {
            "product_name": "OPNsense",
            "product_version": "23.7.12",
            "product_arch": "amd64"
        }
    }

@router.get("/menu/search")
async def search_menu() -> Dict[str, Any]:
    """Search menu items"""
    return {
        "status": "ok",
        "items": [
            {
                "id": "System",
                "name": "System",
                "url": "/system_general.php"
            },
            {
                "id": "Interfaces",
                "name": "Interfaces",
                "url": "/interfaces_overview.php"
            },
            {
                "id": "Firewall",
                "name": "Firewall",
                "url": "/firewall_rules.php"
            }
        ]
    }

@router.get("/trust/status")
async def get_trust_status() -> Dict[str, Any]:
    """Get trust/certificate status"""
    return {
        "status": "ok",
        "certificates": {
            "web": {
                "valid_from": "2024-01-01 00:00:00",
                "valid_to": "2025-01-01 00:00:00",
                "issuer": "OPNsense Test CA",
                "subject": "localhost"
            }
        }
    }
