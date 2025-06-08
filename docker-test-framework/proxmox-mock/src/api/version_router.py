"""
Version API Router for Proxmox VE Mock
Handles version and system information endpoints
"""

from fastapi import APIRouter, Depends
from typing import Dict, Any
import time

router = APIRouter()

@router.get("/version")
async def get_version() -> Dict[str, Any]:
    """Get Proxmox VE version information"""
    return {
        "data": {
            "version": "8.1.4",
            "release": "1",
            "repoid": "d258d382",
            "keyboard": "en-us",
            "console": "xtermjs"
        }
    }

@router.get("/cluster/status")
async def get_cluster_status() -> Dict[str, Any]:
    """Get cluster status"""
    return {
        "data": [
            {
                "type": "cluster",
                "id": "cluster",
                "name": "test-cluster",
                "version": 1,
                "nodes": 1,
                "quorate": 1
            },
            {
                "type": "node",
                "id": "node/pve",
                "name": "pve",
                "online": 1,
                "local": 1,
                "nodeid": 1,
                "ip": "172.20.0.2"
            }
        ]
    }

@router.get("/cluster/resources")
async def get_cluster_resources() -> Dict[str, Any]:
    """Get cluster resources"""
    return {
        "data": [
            {
                "id": "node/pve",
                "type": "node",
                "node": "pve",
                "status": "online",
                "uptime": int(time.time() - 3600),  # 1 hour uptime
                "cpu": 0.15,
                "maxcpu": 4,
                "mem": 2147483648,  # 2GB
                "maxmem": 8589934592,  # 8GB
                "disk": 32212254720,  # 30GB
                "maxdisk": 107374182400,  # 100GB
                "level": ""
            }
        ]
    }
