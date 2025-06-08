"""
Diagnostics API Router for OPNsense Mock
Handles diagnostics and troubleshooting
"""

from fastapi import APIRouter
from typing import Dict, Any

router = APIRouter()

@router.get("/interface")
async def get_interface_diagnostics() -> Dict[str, Any]:
    """Get interface diagnostics"""
    return {
        "status": "ok",
        "interfaces": {
            "lan": {
                "status": "up",
                "speed": "1000Mbps",
                "duplex": "full",
                "rx_packets": 12345,
                "tx_packets": 12340
            },
            "wan": {
                "status": "up",
                "speed": "1000Mbps",
                "duplex": "full",
                "rx_packets": 54321,
                "tx_packets": 54320
            }
        }
    }
