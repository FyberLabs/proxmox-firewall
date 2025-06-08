"""
System API Router for OPNsense Mock
Handles system configuration and status
"""

from fastapi import APIRouter
from typing import Dict, Any
import time

router = APIRouter()

@router.get("/status")
async def get_system_status() -> Dict[str, Any]:
    """Get system status"""
    return {
        "status": "ok",
        "uptime": int(time.time() - 3600),
        "load": [0.1, 0.15, 0.2],
        "memory": {
            "used": 2147483648,  # 2GB
            "total": 4294967296,  # 4GB
            "free": 2147483648   # 2GB
        },
        "cpu": {
            "usage": 15.5,
            "cores": 2,
            "model": "Test CPU"
        }
    }
