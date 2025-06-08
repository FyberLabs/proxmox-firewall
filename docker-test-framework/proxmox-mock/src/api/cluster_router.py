"""
Cluster API Router for Proxmox VE Mock
Handles cluster management endpoints
"""

from fastapi import APIRouter
from typing import Dict, Any
import time

router = APIRouter()

@router.get("/status")
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

@router.get("/resources")
async def get_cluster_resources() -> Dict[str, Any]:
    """Get cluster resources"""
    return {
        "data": [
            {
                "id": "node/pve",
                "type": "node",
                "node": "pve",
                "status": "online",
                "uptime": int(time.time() - 3600),
                "cpu": 0.15,
                "maxcpu": 4,
                "mem": 2147483648,
                "maxmem": 8589934592,
                "disk": 32212254720,
                "maxdisk": 107374182400,
                "level": ""
            }
        ]
    }

@router.get("/config")
async def get_cluster_config() -> Dict[str, Any]:
    """Get cluster configuration"""
    return {
        "data": {
            "cluster_name": "test-cluster",
            "version": 1,
            "nodes": {
                "pve": {
                    "name": "pve",
                    "nodeid": 1,
                    "ring0_addr": "172.20.0.2"
                }
            }
        }
    }
