#!/usr/bin/env python3
"""
Network Topology Simulator
Simulates network interfaces, bridges, and VLANs for testing
"""

import os
from fastapi import FastAPI
import uvicorn
import structlog

logger = structlog.get_logger(__name__)

# Configuration
class Settings:
    def __init__(self):
        self.port = int(os.getenv("NETWORK_SIM_PORT", "8080"))
        self.host = os.getenv("NETWORK_SIM_HOST", "0.0.0.0")
        self.debug = os.getenv("NETWORK_SIM_DEBUG", "false").lower() == "true"

settings = Settings()

# Create FastAPI app
app = FastAPI(
    title="Network Topology Simulator",
    description="Simulates network topology for testing",
    version="1.0.0",
    debug=settings.debug
)

@app.on_event("startup")
async def startup_event():
    """Initialize network simulation"""
    logger.info("Starting Network Topology Simulator")
    # Initialize default network topology here
    logger.info("Network simulation started")

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Network Topology Simulator",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "network-sim"}

if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host=settings.host,
        port=settings.port,
        log_level="debug" if settings.debug else "info"
    )
