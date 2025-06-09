#!/usr/bin/env python3
"""
OPNsense API Mock Service
Simulates OPNsense firewall REST API for testing purposes
"""

import logging
import os
import sys
from typing import Dict, Any, Optional
import uvicorn
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import structlog

from .api import (
    core_router,
    firewall_router,
    interfaces_router,
    system_router,
    diagnostics_router
)
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
        self.port = int(os.getenv("OPNSENSE_MOCK_PORT", "443"))
        self.host = os.getenv("OPNSENSE_MOCK_HOST", "0.0.0.0")
        self.debug = os.getenv("OPNSENSE_MOCK_DEBUG", "false").lower() == "true"
        self.api_version = os.getenv("OPNSENSE_MOCK_API_VERSION", "v1")
        self.interfaces = os.getenv("OPNSENSE_MOCK_INTERFACES", "lan,wan,opt1,opt2").split(",")
        self.data_dir = os.getenv("OPNSENSE_MOCK_DATA_DIR", "/var/lib/opnsense-mock")
        self.ssl_cert = "/app/certs/cert.pem"
        self.ssl_key = "/app/certs/key.pem"

settings = Settings()

# Create FastAPI app
app = FastAPI(
    title="OPNsense API Mock",
    description="Mock service for OPNsense firewall REST API",
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
        "username": "root",
        "scope": "system",
        "permissions": ["*"]
    }

# Dependency to get storage
def get_storage() -> MemoryStorage:
    return storage

# Include API routers
app.include_router(
    core_router.router,
    prefix="/api/core",
    tags=["core"]
)

app.include_router(
    firewall_router.router,
    prefix="/api/firewall",
    tags=["firewall"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    interfaces_router.router,
    prefix="/api/interfaces",
    tags=["interfaces"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    system_router.router,
    prefix="/api/system",
    tags=["system"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    diagnostics_router.router,
    prefix="/api/diagnostics",
    tags=["diagnostics"],
    dependencies=[Depends(get_current_user)]
)

# Add specialized security testing endpoints without /core prefix for direct access
from fastapi import APIRouter
security_router = APIRouter()

@security_router.post("/ids/test-detection")
async def ids_test_detection(request_data: Dict[str, Any]):
    """IDS test detection endpoint - direct access"""
    return await core_router.test_ids_detection(request_data, True)

@security_router.post("/tailscale/test-connection")
async def tailscale_test_connection(request_data: Dict[str, Any]):
    """Tailscale test connection endpoint - direct access"""
    return await core_router.test_tailscale_connection(request_data, True)

app.include_router(
    security_router,
    prefix="/api",
    tags=["security"]
)

@app.on_event("startup")
async def startup_event():
    """Initialize the mock service on startup"""
    logger.info("Starting OPNsense API Mock Service",
                port=settings.port,
                debug=settings.debug,
                interfaces=settings.interfaces)

    # Initialize default data
    await storage.initialize_defaults(settings)

    logger.info("OPNsense API Mock Service started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down OPNsense API Mock Service")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "OPNsense API Mock",
        "version": "1.0.0",
        "status": "running",
        "api_version": settings.api_version,
        "endpoints": [
            "/api/core/firmware/status",
            "/api/firewall/alias",
            "/api/interfaces/overview",
            "/api/system/status",
            "/api/diagnostics/interface"
        ]
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "opnsense-mock"}

if __name__ == "__main__":
    log_level = "debug" if settings.debug else "info"

    uvicorn.run(
        "src.main:app",
        host=settings.host,
        port=settings.port,
        log_level=log_level,
        reload=settings.debug,
        access_log=settings.debug,
        ssl_keyfile=settings.ssl_key,
        ssl_certfile=settings.ssl_cert
    )
