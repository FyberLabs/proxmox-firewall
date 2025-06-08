"""
Memory Storage for Proxmox VE Mock
Handles in-memory storage of VMs, nodes, and configuration data
"""

from typing import Dict, List, Any, Optional
import time
import json
import aiofiles
import structlog

logger = structlog.get_logger(__name__)

class MemoryStorage:
    """In-memory storage for mock Proxmox data"""

    def __init__(self):
        self.vms: Dict[int, Dict[str, Any]] = {}
        self.nodes: Dict[str, Dict[str, Any]] = {}
        self.storage: Dict[str, Dict[str, Any]] = {}
        self.templates: Dict[int, Dict[str, Any]] = {}
        self.tasks: Dict[str, Dict[str, Any]] = {}
        self.initialized = False

    async def initialize_defaults(self, settings) -> None:
        """Initialize default data for testing"""
        if self.initialized:
            return

        logger.info("Initializing storage with default data")

        # Initialize default nodes
        for node_name in settings.nodes:
            self.nodes[node_name] = {
                "node": node_name,
                "status": "online",
                "cpu": 0.15,
                "maxcpu": 4,
                "mem": 2147483648,  # 2GB
                "maxmem": 8589934592,  # 8GB
                "uptime": int(time.time() - 3600),
                "disk": 32212254720,  # 30GB
                "maxdisk": 107374182400,  # 100GB
                "level": "",
                "id": f"node/{node_name}",
                "type": "node"
            }

        # Initialize default storage
        for storage_name in settings.storage:
            self.storage[storage_name] = {
                "storage": storage_name,
                "type": "lvm" if "lvm" in storage_name else "dir",
                "active": 1,
                "used": 21474836480,  # 20GB
                "total": 107374182400,  # 100GB
                "avail": 85899345920,  # 80GB
                "content": "images,rootdir" if "lvm" in storage_name else "iso,vztmpl,backup"
            }

        # Create default VM templates
        await self.create_vm({
            "vmid": 9000,
            "name": "opnsense-template",
            "node": "pve",
            "memory": 4096,
            "cores": 2,
            "sockets": 1,
            "ostype": "other",
            "status": "stopped",
            "template": True,
            "disk_size": 8,
            "created": int(time.time())
        })

        await self.create_vm({
            "vmid": 9001,
            "name": "ubuntu-template",
            "node": "pve",
            "memory": 2048,
            "cores": 2,
            "sockets": 1,
            "ostype": "l26",
            "status": "stopped",
            "template": True,
            "disk_size": 32,
            "created": int(time.time())
        })

        self.initialized = True
        logger.info("Storage initialization completed")

    async def create_vm(self, vm_data: Dict[str, Any]) -> None:
        """Create a new VM"""
        vmid = vm_data["vmid"]
        self.vms[vmid] = vm_data.copy()
        logger.info("VM created", vmid=vmid, name=vm_data.get("name"))

    async def get_vm(self, vmid: int) -> Optional[Dict[str, Any]]:
        """Get VM by ID"""
        return self.vms.get(vmid)

    async def get_vms(self) -> List[Dict[str, Any]]:
        """Get all VMs"""
        return list(self.vms.values())

    async def update_vm(self, vmid: int, updates: Dict[str, Any]) -> None:
        """Update VM configuration"""
        if vmid in self.vms:
            self.vms[vmid].update(updates)
            logger.info("VM updated", vmid=vmid, updates=updates)

    async def delete_vm(self, vmid: int) -> None:
        """Delete a VM"""
        if vmid in self.vms:
            del self.vms[vmid]
            logger.info("VM deleted", vmid=vmid)

    async def get_nodes(self) -> List[Dict[str, Any]]:
        """Get all nodes"""
        return list(self.nodes.values())

    async def get_node(self, node_name: str) -> Optional[Dict[str, Any]]:
        """Get node by name"""
        return self.nodes.get(node_name)

    async def get_storage_list(self) -> List[Dict[str, Any]]:
        """Get all storage"""
        return list(self.storage.values())

    async def get_storage(self, storage_name: str) -> Optional[Dict[str, Any]]:
        """Get storage by name"""
        return self.storage.get(storage_name)

    async def save_to_file(self, filepath: str) -> None:
        """Save current state to file"""
        try:
            data = {
                "vms": self.vms,
                "nodes": self.nodes,
                "storage": self.storage,
                "templates": self.templates,
                "timestamp": int(time.time())
            }

            async with aiofiles.open(filepath, 'w') as f:
                await f.write(json.dumps(data, indent=2))

            logger.info("State saved to file", filepath=filepath)
        except Exception as e:
            logger.error("Failed to save state", filepath=filepath, error=str(e))

    async def load_from_file(self, filepath: str) -> None:
        """Load state from file"""
        try:
            async with aiofiles.open(filepath, 'r') as f:
                content = await f.read()
                data = json.loads(content)

            self.vms = {int(k): v for k, v in data.get("vms", {}).items()}
            self.nodes = data.get("nodes", {})
            self.storage = data.get("storage", {})
            self.templates = {int(k): v for k, v in data.get("templates", {}).items()}

            logger.info("State loaded from file", filepath=filepath)
        except Exception as e:
            logger.error("Failed to load state", filepath=filepath, error=str(e))

    def get_stats(self) -> Dict[str, Any]:
        """Get storage statistics"""
        return {
            "vms": len(self.vms),
            "nodes": len(self.nodes),
            "storage_pools": len(self.storage),
            "templates": len([vm for vm in self.vms.values() if vm.get("template", False)]),
            "running_vms": len([vm for vm in self.vms.values() if vm.get("status") == "running"])
        }
