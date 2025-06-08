"""
Access API Router for Proxmox VE Mock
Handles authentication and user management
"""

from fastapi import APIRouter, HTTPException, Form
from typing import Dict, Any
import time
import uuid

router = APIRouter()

@router.post("/ticket")
async def create_ticket(
    username: str = Form(...),
    password: str = Form(...),
    realm: str = Form(default="pam")
) -> Dict[str, Any]:
    """Create authentication ticket"""
    # Mock authentication - accept any credentials in test mode
    if username and password:
        ticket = f"PVE:{username}@{realm}:{int(time.time())}"
        csrf_token = str(uuid.uuid4())

        return {
            "data": {
                "username": username,
                "ticket": ticket,
                "CSRFPreventionToken": csrf_token,
                "cap": {
                    "storage": {"Datastore.Allocate": 1},
                    "vms": {"VM.Allocate": 1, "VM.Config.CDROM": 1},
                    "nodes": {"Sys.Console": 1}
                }
            }
        }
    else:
        raise HTTPException(status_code=401, detail="Authentication failed")

@router.get("/users")
async def list_users() -> Dict[str, Any]:
    """List users"""
    return {
        "data": [
            {
                "userid": "root@pam",
                "comment": "Built-in Superuser",
                "enable": 1,
                "expire": 0,
                "firstname": "Super",
                "lastname": "User",
                "email": "admin@test.local"
            }
        ]
    }

@router.get("/permissions")
async def get_permissions() -> Dict[str, Any]:
    """Get permissions"""
    return {
        "data": {
            "/": ["Datastore.Allocate", "VM.Allocate", "Sys.Console"],
            "/nodes": ["Sys.Console"],
            "/storage": ["Datastore.Allocate"],
            "/vms": ["VM.Allocate", "VM.Config.CDROM"]
        }
    }
