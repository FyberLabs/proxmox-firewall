"""
Pydantic models for Proxmox VE Mock Service
"""

from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field

class ProxmoxConfig(BaseModel):
    """Configuration for Proxmox mock service"""
    nodes: List[str] = Field(default=["pve"])
    storage: List[str] = Field(default=["local", "local-lvm"])
    debug: bool = Field(default=False)
    port: int = Field(default=8006)
    host: str = Field(default="0.0.0.0")

class VMConfig(BaseModel):
    """VM configuration model"""
    vmid: int
    name: Optional[str] = None
    memory: Optional[int] = 2048
    cores: Optional[int] = 2
    sockets: Optional[int] = 1
    ostype: Optional[str] = "l26"
    status: Optional[str] = "stopped"
    template: Optional[bool] = False
    node: Optional[str] = "pve"

class NodeInfo(BaseModel):
    """Node information model"""
    node: str
    status: str = "online"
    cpu: float = 0.0
    maxcpu: int = 4
    mem: int = 0
    maxmem: int = 8589934592  # 8GB
    uptime: int = 0
    disk: int = 0
    maxdisk: int = 107374182400  # 100GB

class StorageInfo(BaseModel):
    """Storage information model"""
    storage: str
    type: str
    active: int = 1
    used: int = 0
    total: int = 107374182400  # 100GB
    avail: int = 107374182400  # 100GB
    content: str = "images,rootdir"
