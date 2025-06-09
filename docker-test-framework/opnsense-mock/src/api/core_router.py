"""
Core API Router for OPNsense Mock
Handles core system endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Dict, Any, Optional
import time
import uuid
import json

router = APIRouter()
security = HTTPBearer(auto_error=False)

def verify_authentication(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> bool:
    """Verify API authentication"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Mock authentication - only accept "test-key" for security testing
    if credentials.credentials != "test-key":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return True

@router.get("/system/status")
async def get_system_status(authenticated: bool = Depends(verify_authentication)) -> Dict[str, Any]:
    """Get system status - requires authentication"""
    return {
        "status": "running",
        "uptime": "5 days, 12:34:56",
        "load_average": [0.15, 0.18, 0.22],
        "memory": {
            "total": "8GB",
            "used": "2.1GB",
            "free": "5.9GB"
        },
        "disk": {
            "total": "100GB",
            "used": "15GB",
            "free": "85GB"
        },
        "services": {
            "firewall": "running",
            "ids": "running",
            "vpn": "running"
        },
        "timestamp": int(time.time())
    }

@router.get("/firmware/status")
async def get_firmware_status() -> Dict[str, Any]:
    """Get firmware status"""
    return {
        "status": "ok",
        "status_msg": "Firmware is up to date",
        "last_check": int(time.time()),
        "updates": 0,
        "upgrade_needs_reboot": False,
        "connection": "ok",
        "repository": "OPNsense",
        "product": {
            "product_name": "OPNsense",
            "product_version": "23.7.12",
            "product_arch": "amd64"
        }
    }

@router.get("/menu/search")
async def search_menu() -> Dict[str, Any]:
    """Search menu items"""
    return {
        "status": "ok",
        "items": [
            {
                "id": "System",
                "name": "System",
                "url": "/system_general.php"
            },
            {
                "id": "Interfaces",
                "name": "Interfaces",
                "url": "/interfaces_overview.php"
            },
            {
                "id": "Firewall",
                "name": "Firewall",
                "url": "/firewall_rules.php"
            }
        ]
    }

@router.get("/trust/status")
async def get_trust_status() -> Dict[str, Any]:
    """Get trust/certificate status"""
    return {
        "status": "ok",
        "certificates": {
            "web": {
                "valid_from": "2024-01-01 00:00:00",
                "valid_to": "2025-01-01 00:00:00",
                "issuer": "OPNsense Test CA",
                "subject": "localhost"
            }
        }
    }

# Enhanced security testing endpoints

@router.post("/backup")
async def create_backup(
    request_data: Dict[str, Any],
    authenticated: bool = Depends(verify_authentication)
) -> Dict[str, Any]:
    """Create system backup"""
    backup_id = str(uuid.uuid4())

    return {
        "status": "ok",
        "backup_id": backup_id,
        "size": "45MB",
        "created": int(time.time()),
        "includes": ["config", "certificates", "firewall_rules"],
        "message": "Backup created successfully"
    }

@router.post("/restore/test")
async def test_restore(
    request_data: Dict[str, Any],
    authenticated: bool = Depends(verify_authentication)
) -> Dict[str, Any]:
    """Test backup restore capability"""
    backup_id = request_data.get("backup_id")

    if not backup_id:
        raise HTTPException(status_code=400, detail="Missing backup_id")

    return {
        "status": "ok",
        "validation_status": "valid",
        "backup_id": backup_id,
        "size": "45MB",
        "components": ["config", "certificates", "firewall_rules"],
        "estimated_restore_time": "2 minutes",
        "message": "Backup is valid and can be restored"
    }

# IDS/IPS simulation endpoints

@router.post("/ids/test-detection")
async def test_ids_detection(
    request_data: Dict[str, Any],
    authenticated: bool = Depends(verify_authentication)
) -> Dict[str, Any]:
    """Test IDS/IPS detection capabilities"""
    attack_type = request_data.get("attack_type")
    source = request_data.get("source")
    destination = request_data.get("destination")

    # Map attack types to alert types for testing
    alert_mapping = {
        "' OR '1'='1": "SQL_INJECTION",
        "rapid_port_scan": "PORT_SCAN",
        "ssh_brute_force": "BRUTE_FORCE"
    }

    alert_type = alert_mapping.get(attack_type, "UNKNOWN_ATTACK")

    return {
        "status": "detected",
        "alert_type": alert_type,
        "source": source,
        "destination": destination,
        "severity": "high" if alert_type != "UNKNOWN_ATTACK" else "low",
        "timestamp": int(time.time()),
        "rule_id": f"SID:{hash(attack_type) % 100000}",
        "message": f"IDS detected {alert_type.lower()} from {source} to {destination}"
    }

# Tailscale VPN simulation endpoints

@router.post("/tailscale/test-connection")
async def test_tailscale_connection(
    request_data: Dict[str, Any],
    authenticated: bool = Depends(verify_authentication)
) -> Dict[str, Any]:
    """Test Tailscale VPN connection"""
    peer_ip = request_data.get("peer_ip")
    destination = request_data.get("destination")
    port = request_data.get("port")

    # Simulate successful VPN connection for testing
    return {
        "status": "ok",
        "connection_status": "established",
        "peer_ip": peer_ip,
        "destination": destination,
        "port": port,
        "tunnel_type": "tailscale",
        "encryption": "ChaCha20Poly1305",
        "latency_ms": 25,
        "timestamp": int(time.time()),
        "message": f"VPN connection established to {destination}:{port} via {peer_ip}"
    }

@router.get("/tailscale/status")
async def get_tailscale_status(
    authenticated: bool = Depends(verify_authentication)
) -> Dict[str, Any]:
    """Get Tailscale VPN status"""
    return {
        "status": "connected",
        "node_name": "opnsense-test",
        "tailnet": "test-tailnet.ts.net",
        "peers": [
            {
                "ip": "100.64.0.2",
                "name": "admin-laptop",
                "status": "online",
                "last_seen": int(time.time()) - 30
            },
            {
                "ip": "100.64.0.3",
                "name": "mobile-device",
                "status": "online",
                "last_seen": int(time.time()) - 120
            }
        ],
        "advertised_routes": ["10.0.0.0/16"],
        "exit_node": False,
        "timestamp": int(time.time())
    }

# System monitoring endpoints

@router.get("/monitoring/alerts")
async def get_monitoring_alerts(
    authenticated: bool = Depends(verify_authentication)
) -> Dict[str, Any]:
    """Get system monitoring alerts"""
    return {
        "status": "ok",
        "alerts": [
            {
                "id": str(uuid.uuid4()),
                "type": "security",
                "severity": "medium",
                "message": "Multiple failed login attempts detected",
                "timestamp": int(time.time()) - 300,
                "source": "192.168.1.100"
            },
            {
                "id": str(uuid.uuid4()),
                "type": "network",
                "severity": "low",
                "message": "High bandwidth usage on WAN interface",
                "timestamp": int(time.time()) - 600,
                "interface": "wan"
            }
        ],
        "total_alerts": 2,
        "new_alerts": 1
    }
