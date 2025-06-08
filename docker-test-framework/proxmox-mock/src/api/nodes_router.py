"""
Nodes API Router for Proxmox VE Mock
Handles node and VM management endpoints
"""

from fastapi import APIRouter, HTTPException, Depends, Body
from typing import Dict, Any, List, Optional
import time
import uuid
from pydantic import BaseModel

from ..storage import MemoryStorage

router = APIRouter()

class VMCreateRequest(BaseModel):
    vmid: int
    name: Optional[str] = None
    memory: Optional[int] = 2048
    cores: Optional[int] = 2
    sockets: Optional[int] = 1
    ostype: Optional[str] = "l26"
    net0: Optional[str] = "virtio,bridge=vmbr0"
    scsi0: Optional[str] = None
    ide2: Optional[str] = None
    boot: Optional[str] = "order=scsi0;ide2"
    agent: Optional[int] = 1

class VMConfigUpdate(BaseModel):
    memory: Optional[int] = None
    cores: Optional[int] = None
    net0: Optional[str] = None
    description: Optional[str] = None

@router.get("")
async def list_nodes() -> Dict[str, Any]:
    """List all nodes in the cluster"""
    return {
        "data": [
            {
                "node": "pve",
                "status": "online",
                "cpu": 0.15,
                "maxcpu": 4,
                "mem": 2147483648,
                "maxmem": 8589934592,
                "uptime": int(time.time() - 3600),
                "disk": 32212254720,
                "maxdisk": 107374182400,
                "level": "",
                "id": "node/pve",
                "type": "node"
            }
        ]
    }

@router.get("/{node}")
async def get_node_info(node: str) -> Dict[str, Any]:
    """Get specific node information"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    return {
        "data": {
            "node": "pve",
            "status": "online",
            "cpu": 0.15,
            "maxcpu": 4,
            "mem": 2147483648,
            "maxmem": 8589934592,
            "uptime": int(time.time() - 3600),
            "disk": 32212254720,
            "maxdisk": 107374182400,
            "loadavg": [0.08, 0.12, 0.15],
            "pveversion": "pve-manager/8.1.4/ec5affc9e2be2133 (running kernel: 6.5.11-8-pve)",
            "kversion": "Linux 6.5.11-8-pve #1 SMP PREEMPT_DYNAMIC PMX 6.5.11-8 (2023-12-05T09:44Z)"
        }
    }

@router.get("/{node}/qemu")
async def list_vms(node: str, storage: MemoryStorage = Depends()) -> Dict[str, Any]:
    """List all VMs on a node"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    vms = await storage.get_vms()
    vm_list = []

    for vm in vms:
        vm_list.append({
            "vmid": vm["vmid"],
            "name": vm.get("name", f"VM{vm['vmid']}"),
            "status": vm.get("status", "stopped"),
            "maxmem": vm.get("memory", 2048) * 1024 * 1024,
            "mem": int(vm.get("memory", 2048) * 1024 * 1024 * 0.5) if vm.get("status") == "running" else 0,
            "maxcpu": vm.get("cores", 2),
            "cpu": 0.15 if vm.get("status") == "running" else 0,
            "maxdisk": vm.get("disk_size", 32) * 1024 * 1024 * 1024,
            "disk": int(vm.get("disk_size", 32) * 1024 * 1024 * 1024 * 0.3),
            "uptime": int(time.time() - 1800) if vm.get("status") == "running" else 0,
            "template": vm.get("template", False)
        })

    return {"data": vm_list}

@router.post("/{node}/qemu")
async def create_vm(
    node: str,
    vm_data: VMCreateRequest,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Create a new VM"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    # Check if VM ID already exists
    existing_vms = await storage.get_vms()
    if any(vm["vmid"] == vm_data.vmid for vm in existing_vms):
        raise HTTPException(status_code=400, detail=f"VM {vm_data.vmid} already exists")

    # Create VM record
    vm_record = {
        "vmid": vm_data.vmid,
        "name": vm_data.name or f"VM{vm_data.vmid}",
        "node": node,
        "memory": vm_data.memory,
        "cores": vm_data.cores,
        "sockets": vm_data.sockets,
        "ostype": vm_data.ostype,
        "status": "stopped",
        "template": False,
        "disk_size": 32,  # Default 32GB
        "created": int(time.time())
    }

    await storage.create_vm(vm_record)

    task_id = str(uuid.uuid4())
    return {
        "data": task_id
    }

@router.get("/{node}/qemu/{vmid}/config")
async def get_vm_config(
    node: str,
    vmid: int,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Get VM configuration"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    vm = await storage.get_vm(vmid)
    if not vm:
        raise HTTPException(status_code=404, detail="VM not found")

    config = {
        "vmid": vm["vmid"],
        "name": vm.get("name", f"VM{vm['vmid']}"),
        "memory": vm.get("memory", 2048),
        "cores": vm.get("cores", 2),
        "sockets": vm.get("sockets", 1),
        "ostype": vm.get("ostype", "l26"),
        "boot": "order=scsi0;ide2",
        "agent": "1",
        "net0": "virtio=52:54:00:12:34:56,bridge=vmbr0",
        "scsi0": f"local-lvm:vm-{vmid}-disk-0,size=32G",
        "scsihw": "virtio-scsi-pci",
        "ide2": "local:iso/ubuntu-22.04.3-live-server-amd64.iso,media=cdrom"
    }

    return {"data": config}

@router.put("/{node}/qemu/{vmid}/config")
async def update_vm_config(
    node: str,
    vmid: int,
    config_update: VMConfigUpdate,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Update VM configuration"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    vm = await storage.get_vm(vmid)
    if not vm:
        raise HTTPException(status_code=404, detail="VM not found")

    # Update VM with new configuration
    updates = {}
    if config_update.memory is not None:
        updates["memory"] = config_update.memory
    if config_update.cores is not None:
        updates["cores"] = config_update.cores
    if config_update.description is not None:
        updates["description"] = config_update.description

    await storage.update_vm(vmid, updates)

    task_id = str(uuid.uuid4())
    return {"data": task_id}

@router.post("/{node}/qemu/{vmid}/status/start")
async def start_vm(
    node: str,
    vmid: int,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Start a VM"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    vm = await storage.get_vm(vmid)
    if not vm:
        raise HTTPException(status_code=404, detail="VM not found")

    await storage.update_vm(vmid, {"status": "running"})

    task_id = str(uuid.uuid4())
    return {"data": task_id}

@router.post("/{node}/qemu/{vmid}/status/stop")
async def stop_vm(
    node: str,
    vmid: int,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Stop a VM"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    vm = await storage.get_vm(vmid)
    if not vm:
        raise HTTPException(status_code=404, detail="VM not found")

    await storage.update_vm(vmid, {"status": "stopped"})

    task_id = str(uuid.uuid4())
    return {"data": task_id}

@router.delete("/{node}/qemu/{vmid}")
async def delete_vm(
    node: str,
    vmid: int,
    storage: MemoryStorage = Depends()
) -> Dict[str, Any]:
    """Delete a VM"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    vm = await storage.get_vm(vmid)
    if not vm:
        raise HTTPException(status_code=404, detail="VM not found")

    await storage.delete_vm(vmid)

    task_id = str(uuid.uuid4())
    return {"data": task_id}

@router.get("/{node}/storage")
async def list_storage(node: str) -> Dict[str, Any]:
    """List storage on a node"""
    if node != "pve":
        raise HTTPException(status_code=404, detail="Node not found")

    return {
        "data": [
            {
                "storage": "local",
                "type": "dir",
                "active": 1,
                "used": 5368709120,  # 5GB
                "total": 107374182400,  # 100GB
                "avail": 102005473280,  # 95GB
                "content": "iso,vztmpl,backup"
            },
            {
                "storage": "local-lvm",
                "type": "lvm",
                "active": 1,
                "used": 21474836480,  # 20GB
                "total": 107374182400,  # 100GB
                "avail": 85899345920,  # 80GB
                "content": "images,rootdir"
            }
        ]
    }
