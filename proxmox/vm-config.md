# VM Configuration

## Overview

Full KVM virtual machines are used when LXC containers aren't suitable — specifically for PCIe passthrough (TrueNAS) and Windows workloads (DC01).

## VM Summary

|ID|Name|vCPU|RAM|Storage|Purpose|
|---|---|---|---|---|---|
|100|truenas|4|16GB (no ballooning)|20GB + Passthrough|ZFS Storage Server|
|104|dc01|4|8GB|60GB|Windows Domain Controller|

## VM 100 — TrueNAS SCALE

**Purpose:** Centralized storage server providing NFS/SMB shares

### Hardware Configuration

|Component|Setting|
|---|---|
|Machine Type|q35|
|BIOS|OVMF (UEFI)|
|CPU|host (passthrough)|
|vCPU|4 cores|
|RAM|16GB (ballooning off — ZFS ARC needs fixed memory)|
|Boot|Startup order 3, then 120 s delay before the Docker LXC|
|Network|VirtIO on vmbr0, VLAN 21|

### Disk Configuration

|Disk|Type|Purpose|
|---|---|---|
|scsi0|Virtual disk (20GB, SSD emulation, discard, iothread)|TrueNAS OS (boot-pool)|
|hostpci0|PCIe Passthrough (`0000:00:17`)|Onboard SATA AHCI controller (3 data disks)|

### PCIe Passthrough Setup

The onboard SATA controller is passed through directly to TrueNAS for optimal ZFS performance. The host itself boots from NVMe, so it never needs the SATA controller. Full write-up: [truenas/disk-passthrough.md](../truenas/disk-passthrough.md).

**VFIO Modules (`/etc/modules`):**

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

**Claim the controller for vfio-pci at boot (`/etc/modprobe.d/vfio-truenas-sata.conf`):**

```
options vfio-pci ids=8086:7a62
softdep ahci pre: vfio-pci
```

Then `update-initramfs -u -k all`. The IOMMU is on by default with this kernel, so no extra GRUB parameters are needed.

**Host ZFS import disabled:** the host has no ZFS pools of its own, so `zfs-import-scan` and `zfs-import-cache` are masked. Before this, the host scanned TrueNAS's disks at every boot and found its pools; only ZFS's "pool in use by another system" check prevented an import.

### Network Configuration

- Interface: VirtIO NIC
- Bridge: vmbr0
- VLAN: 21 (untagged)
- Proxmox firewall bridge enabled
- IP: Static (10.2.1.x/24)

## VM 104 — DC01 (Domain Controller)

**Purpose:** Windows Server for Active Directory lab/testing

### Hardware Configuration

| Component    | Setting                  |
| ------------ | ------------------------ |
| Machine Type | q35                      |
| BIOS         | OVMF (UEFI)              |
| CPU          | x86-64-v2-AES            |
| vCPU         | 4 cores                  |
| RAM          | 8GB                      |
| Network      | e1000 on vmbr0, VLAN 21  |
| Disk         | 60GB IDE                 |

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