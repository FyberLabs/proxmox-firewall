#!/usr/bin/env python3
"""
Proxmox VE API Mock Service
Simulates Proxmox VE REST API for testing purposes
"""

import logging
import os
import sys
import time
from typing import Dict, Any, Optional
import uvicorn
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import structlog

from .api import (
    version_router,
    nodes_router,
    storage_router,
    cluster_router,
    access_router
)
from .models import ProxmoxConfig
from .storage import MemoryStorage

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)

# Configuration
class Settings:
    def __init__(self):
        self.port = int(os.getenv("PROXMOX_MOCK_PORT", "8006"))
        self.host = os.getenv("PROXMOX_MOCK_HOST", "0.0.0.0")
        self.debug = os.getenv("PROXMOX_MOCK_DEBUG", "false").lower() == "true"
        self.api_version = os.getenv("PROXMOX_MOCK_API_VERSION", "v2")
        self.nodes = os.getenv("PROXMOX_MOCK_NODES", "pve").split(",")
        self.storage = os.getenv("PROXMOX_MOCK_STORAGE", "local-lvm").split(",")
        self.data_dir = os.getenv("PROXMOX_MOCK_DATA_DIR", "/var/lib/proxmox-mock")

settings = Settings()

# Create FastAPI app
app = FastAPI(
    title="Proxmox VE API Mock",
    description="Mock service for Proxmox VE REST API",
    version="1.0.0",
    debug=settings.debug
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer(auto_error=False)

# Global storage instance
storage = MemoryStorage()

async def get_current_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> Dict[str, Any]:
    """Mock authentication - always returns valid user in test environment"""
    if not credentials and not settings.debug:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token"
        )

    # In test mode, return a mock user
    return {
        "userid": "root@pam",
        "username": "root",
        "realm": "pam",
        "permissions": ["*"]
    }

# Dependency to get storage
def get_storage() -> MemoryStorage:
    return storage

# Include API routers
app.include_router(
    version_router.router,
    prefix="/api2/json",
    tags=["version"]
)

app.include_router(
    access_router.router,
    prefix="/api2/json/access",
    tags=["access"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    nodes_router.router,
    prefix="/api2/json/nodes",
    tags=["nodes"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    storage_router.router,
    prefix="/api2/json/storage",
    tags=["storage"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    cluster_router.router,
    prefix="/api2/json/cluster",
    tags=["cluster"],
    dependencies=[Depends(get_current_user)]
)

@app.on_event("startup")
async def startup_event():
    """Initialize the mock service on startup"""
    logger.info("Starting Proxmox VE API Mock Service",
                port=settings.port,
                debug=settings.debug,
                nodes=settings.nodes)

    # Initialize default data
    await storage.initialize_defaults(settings)

    logger.info("Proxmox VE API Mock Service started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down Proxmox VE API Mock Service")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Proxmox VE API Mock",
        "version": "1.0.0",
        "status": "running",
        "api_version": settings.api_version,
        "endpoints": [
            "/api2/json/version",
            "/api2/json/access/ticket",
            "/api2/json/nodes",
            "/api2/json/storage",
            "/api2/json/cluster"
        ]
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "proxmox-mock"}

# Enhanced security testing endpoints

@app.post("/api/network/test-connectivity")
async def test_network_connectivity(
    request_data: Dict[str, Any],
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """Test network connectivity through firewall simulation"""
    source = request_data.get("source")
    destination = request_data.get("destination")
    protocol = request_data.get("protocol", "tcp")
    port = request_data.get("port", 80)

    # Simulate network connectivity based on source/destination networks
    result = _simulate_network_connectivity(source, destination, protocol, port)

    return {
        "status": "ok",
        "result": result["status"],
        "source": source,
        "destination": destination,
        "protocol": protocol,
        "port": port,
        "latency_ms": result["latency"],
        "route": result["route"],
                 "timestamp": int(time.time()),
        "message": f"Network test from {source} to {destination}:{port} - {result['status']}"
    }

@app.post("/api/network/test-vlan-isolation")
async def test_vlan_isolation(
    request_data: Dict[str, Any],
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """Test VLAN network isolation"""
    source = request_data.get("source")
    destination = request_data.get("destination")
    protocol = request_data.get("protocol", "icmp")

    # Extract VLAN IDs from IP addresses (assuming 10.0.{vlan}.x format)
    source_vlan = _extract_vlan_from_ip(source)
    dest_vlan = _extract_vlan_from_ip(destination)

    # Simulate VLAN isolation rules
    if source_vlan == dest_vlan:
        result = "allowed"  # Same VLAN
    elif source_vlan == 50:  # Management VLAN can access others
        result = "allowed"
    else:
        result = "blocked"  # Inter-VLAN blocked by default

    return {
        "status": "ok",
        "result": result,
        "source": source,
        "destination": destination,
        "source_vlan": source_vlan,
        "destination_vlan": dest_vlan,
        "protocol": protocol,
        "rule": f"VLAN {source_vlan} to VLAN {dest_vlan}",
                 "timestamp": int(time.time())
    }

@app.post("/api/vm/create")
async def create_vm(
    request_data: Dict[str, Any],
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """Simulate VM creation"""
    vmid = request_data.get("vmid")
    name = request_data.get("name")
    memory = request_data.get("memory", 2048)
    cores = request_data.get("cores", 2)
    template = request_data.get("template")

    if not vmid or not name:
        raise HTTPException(status_code=400, detail="Missing required fields: vmid, name")

    # Generate task ID for VM creation
    task_id = f"UPID:pve:VM{vmid}:task{int(time.time())}"

    # Store VM in mock storage
    vm_data = {
        "vmid": vmid,
        "name": name,
        "memory": memory,
        "cores": cores,
        "template": template,
        "status": "stopped",
                 "created": int(time.time()),
        "node": "pve"
    }

    return {
        "status": "ok",
        "task": task_id,
        "vmid": vmid,
        "name": name,
        "message": f"VM {name} (ID: {vmid}) creation initiated",
        "estimated_time": "5 minutes"
    }

@app.get("/api2/json/nodes/{node}/qemu/{vmid}/status/current")
async def get_vm_status(
    node: str,
    vmid: int,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """Get VM status"""
    return {
        "data": {
            "vmid": vmid,
            "status": "running",
            "name": f"vm-{vmid}",
            "uptime": 86400,  # 1 day
            "memory": {
                "used": 1073741824,  # 1GB
                "total": 2147483648  # 2GB
            },
            "cpu": 0.15,
            "disk": {
                "used": 5368709120,  # 5GB
                "total": 21474836480  # 20GB
            },
            "network": {
                "in": 1048576,  # 1MB
                "out": 2097152  # 2MB
            }
        }
    }

def _simulate_network_connectivity(source: str, destination: str, protocol: str, port: int) -> Dict[str, Any]:
    """Simulate network connectivity based on predefined rules"""
    import time

    # Define network access rules for testing
    if destination == "8.8.8.8":  # Internet access
        if source.startswith("10.0.1."):  # LAN network
            return {"status": "allowed", "latency": 15, "route": "wan_gateway"}
        else:
            return {"status": "blocked", "latency": None, "route": None}

    elif destination.startswith("10.0.") and source.startswith("203.0."):  # WAN to LAN
        if port == 22:  # SSH blocked from WAN
            return {"status": "blocked", "latency": None, "route": None}
        else:
            return {"status": "allowed", "latency": 5, "route": "direct"}

    elif source.startswith("100.64."):  # VPN network
        return {"status": "allowed", "latency": 8, "route": "tailscale_tunnel"}

    else:
        return {"status": "allowed", "latency": 2, "route": "direct"}

def _extract_vlan_from_ip(ip: str) -> int:
    """Extract VLAN ID from IP address (assuming 10.0.{vlan}.x format)"""
    try:
        parts = ip.split(".")
        if len(parts) >= 3 and parts[0] == "10" and parts[1] == "0":
            return int(parts[2])
    except (ValueError, IndexError):
        pass
    return 1  # Default VLAN

if __name__ == "__main__":
    log_level = "debug" if settings.debug else "info"

    uvicorn.run(
        "src.main:app",
        host=settings.host,
        port=settings.port,
        log_level=log_level,
        reload=settings.debug,
        access_log=settings.debug
    )
