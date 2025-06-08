"""
Storage API Router for Proxmox VE Mock
Handles storage management endpoints
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any
from ..storage import MemoryStorage

router = APIRouter()

@router.get("")
async def list_storage(storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """List all storage"""
    storage_list = await storage.get_storage_list()
    return {"data": storage_list}

@router.get("/{storage_id}")
async def get_storage_info(storage_id: str, storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """Get specific storage information"""
    storage_info = await storage.get_storage(storage_id)
    if not storage_info:
        raise HTTPException(status_code=404, detail="Storage not found")

    return {"data": storage_info}

@router.get("/{storage_id}/content")
async def list_storage_content(storage_id: str) -> Dict[str, Any]:
    """List storage content"""
    if storage_id == "local":
        return {
            "data": [
                {
                    "volid": "local:iso/ubuntu-22.04.3-live-server-amd64.iso",
                    "content": "iso",
                    "format": "iso",
                    "size": 1474873344,
                    "ctime": 1640995200
                },
                {
                    "volid": "local:iso/opnsense-23.7-amd64.iso",
                    "content": "iso",
                    "format": "iso",
                    "size": 483729408,
                    "ctime": 1640995200
                }
            ]
        }
    elif storage_id == "local-lvm":
        return {
            "data": [
                {
                    "volid": "local-lvm:vm-9000-disk-0",
                    "content": "images",
                    "format": "raw",
                    "size": 8589934592,  # 8GB
                    "vmid": 9000,
                    "ctime": 1640995200
                },
                {
                    "volid": "local-lvm:vm-9001-disk-0",
                    "content": "images",
                    "format": "raw",
                    "size": 34359738368,  # 32GB
                    "vmid": 9001,
                    "ctime": 1640995200
                }
            ]
        }
    else:
        return {"data": []}

@router.get("/{storage_id}/status")
async def get_storage_status(storage_id: str, storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """Get storage status"""
    storage_info = await storage.get_storage(storage_id)
    if not storage_info:
        raise HTTPException(status_code=404, detail="Storage not found")

    return {
        "data": {
            "storage": storage_id,
            "type": storage_info["type"],
            "active": storage_info["active"],
            "used": storage_info["used"],
            "total": storage_info["total"],
            "avail": storage_info["avail"],
            "enabled": 1
        }
    }
