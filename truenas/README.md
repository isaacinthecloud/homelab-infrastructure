# TrueNAS SCALE

## Overview

TrueNAS SCALE provides enterprise-grade ZFS storage running as a VM on Proxmox with PCIe passthrough for direct disk access.

## System Configuration

|Component|Details|
|---|---|
|TrueNAS Version|SCALE|
|VM ID|100|
|vCPU|4|
|RAM|16GB|
|Network|VLAN 21 (10.2.1.x/24)|
|Disk Access|PCIe Passthrough (SATA Controller)|

## Storage Architecture

### ZFS Pool Design

The storage pool uses ZFS for data integrity, snapshots, and efficient storage management.

**Pool Configuration:**

- Pool Name: `tank`
- RAID Level: raidz1
- Compression: lz4
- Deduplication: Off (unless required for specific use cases)

### Datasets

| Dataset   | Purpose             | Quota | Shared Via |
| --------- | ------------------- | ----- | ---------- |
| Config    | Application configs | None  | NFS        |
| Movies    | Movie library       | None  | NFS        |
| TV_Shows  | TV series library   | None  | NFS        |
| Music     | Music library       | None  | NFS        |
| Downloads | Torrent downloads   | None  | NFS        |

## Key Design Decisions

1. **VM instead of LXC** — Required for PCIe passthrough
2. **PCIe passthrough** — Direct disk access for ZFS, no virtualization overhead
3. **NFS for Linux clients** — Lower overhead than SMB for Docker containers
4. **16GB RAM** — ZFS ARC cache benefits from available memory