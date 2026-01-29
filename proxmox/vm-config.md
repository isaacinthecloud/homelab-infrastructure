# VM Configuration

## Overview

Full KVM virtual machines are used when LXC containers aren't suitable — specifically for PCIe passthrough (TrueNAS) and Windows workloads (DC01).

## VM Summary

|ID|Name|vCPU|RAM|Storage|Purpose|
|---|---|---|---|---|---|
|100|truenas|4|16GB|32GB + Passthrough|ZFS Storage Server|
|104|dc01|4|8GB|20GB|Windows Domain Controller|

## VM 100 — TrueNAS SCALE

**Purpose:** Centralized storage server providing NFS/SMB shares

### Hardware Configuration

|Component|Setting|
|---|---|
|Machine Type|q35|
|BIOS|OVMF (UEFI)|
|CPU|host (passthrough)|
|vCPU|4 cores|
|RAM|16GB|
|Network|VirtIO on vmbr0, VLAN 21|

### Disk Configuration

|Disk|Type|Purpose|
|---|---|---|
|scsi0|Virtual disk (32GB)|TrueNAS OS|
|hostpci0|PCIe Passthrough|SATA/SAS Controller|

### PCIe Passthrough Setup

The SATA controller is passed through directly to TrueNAS for optimal ZFS performance.

**GRUB Configuration (`/etc/default/grub`):**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**VFIO Modules (`/etc/modules`):**

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

**Blacklist onboard drivers (`/etc/modprobe.d/blacklist.conf`):**

```
blacklist ahci
blacklist libahci
```

### Network Configuration

- Interface: VirtIO NIC
- Bridge: vmbr0
- VLAN: 21 (untagged)
- IP: Static (10.2.1.x/24)

## VM 104 — DC01 (Domain Controller)

**Purpose:** Windows Server for Active Directory lab/testing

### Hardware Configuration

| Component    | Setting                  |
| ------------ | ------------------------ |
| Machine Type | q35                      |
| BIOS         | OVMF (UEFI)              |
| CPU          | host                     |
| vCPU         | 4 cores                  |
| RAM          | 8GB                      |
| Network      | VirtIO on vmbr0, VLAN 21 |
| Disk         | 20GB VirtIO SCSI         |

### Use Cases

- PowerShell automation testing
- Active Directory user provisioning scripts
- SQL Server integration testing
- Group Policy experimentation


> **Note:** DC01 is for lab purposes and not included in the primary network topology diagrams. 

## Firewall Bridge Explanation

VMs connect through Proxmox's firewall bridge for traffic inspection:

```
VM NIC → tap100i0 → fwbr100i0 → fwln100i0 ↔ fwpr100p0 → vmbr0 → Physical Network
```

This allows Proxmox firewall rules to filter VM traffic if enabled.