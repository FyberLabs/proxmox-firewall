#!/usr/bin/env python3
"""
Proxmox VE API Mock Service
Simulates Proxmox VE REST API for testing purposes
"""

import logging
import os
import sys
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

if __name__ == "__main__":
    log_level = "debug" if settings.debug else "info"

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        log_level=log_level,
        reload=settings.debug,
        access_log=settings.debug
    )
