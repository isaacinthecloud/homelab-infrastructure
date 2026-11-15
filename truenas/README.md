# TrueNAS SCALE

## Overview

TrueNAS SCALE provides enterprise-grade ZFS storage running as a VM on Proxmox with PCIe passthrough for direct disk access.

## System Configuration

|Component|Details|
|---|---|
|TrueNAS Version|SCALE 25.04 (Fangtooth)|
|VM ID|100|
|vCPU|4|
|RAM|16GB (fixed, no ballooning)|
|Network|VLAN 21 (10.2.1.x/24)|
|Disk Access|PCIe Passthrough (onboard SATA controller)|
|Boot|20GB virtual disk (`boot-pool`)|

## Storage Architecture

### ZFS Pool Design

The storage pool uses ZFS for data integrity, snapshots, and efficient storage management. Full details: [zfs-pool-design.md](zfs-pool-design.md).

**Pool Configuration:**

- Pool Name: `datastore`
- Layout: RAIDZ1, 3 × 14TB enterprise HDDs
- Compression: lz4
- Deduplication: Off

### Datasets

| Dataset | Purpose | Record size | Shared Via |
| ------- | ------- | ----------- | ---------- |
| `data` | Media libraries + torrent downloads (one filesystem → hardlinks) | 1M | NFS → Proxmox host only |
| `isaac` | Personal files | 128K | SMB |
| `isaac/Obsidian` (folder) | Obsidian vault for Syncthing | — | NFS → Proxmox host only |
| `mio` | Second household member's files | 128K | SMB |
| `NAS/nas` | 2TB zvol, block storage for a Windows PC | — | iSCSI |
| `backups/proxmox` | Proxmox guest backups + host config archives | 1M | NFS → Proxmox host only |
| `backups/laptop` | Encrypted restic repository for a Linux laptop | 1M | SFTP (dedicated, restricted user) |

## Data Protection

| What | How |
|---|---|
| Disk failure | RAIDZ1 (survives one disk) + monthly scrub + SMART monitoring |
| Accidental deletion | Snapshot tasks: `isaac` daily (4 weeks), `NAS` weekly recursive (4 weeks), `backups/laptop` daily (4 weeks) |
| Failures go unnoticed | Email alerts (warning and above) via AWS SES — see [monitoring](../monitoring/README.md) |
| VM / config loss | TrueNAS VM backed up weekly by Proxmox to the host's NVMe and uploaded to S3; config exported weekly |
| Site loss | Encrypted off-site copies in AWS S3 Glacier Deep Archive (Cloud Sync + zvol streams) — see [backups/offsite](../backups/offsite/README.md) |

See [backups/README.md](../backups/README.md) for the full backup design.

## Hardening

- SSH: key-only login, weak ciphers (AES128-CBC, NONE) disabled, host keys regenerated
- NFS exports are limited to the single Proxmox host IP, with all access mapped to one non-root user (except the backup share, which needs root)
- The laptop backup account has no shell, no password and a `restrict`-ed SSH key (SFTP only)

## Key Design Decisions

1. **VM instead of LXC** — Required for PCIe passthrough
2. **PCIe passthrough** — Direct disk access for ZFS, no virtualization overhead
3. **NFS only to the hypervisor** — Containers receive bind mounts; no client besides the Proxmox host can mount the NFS shares
4. **16GB RAM** — ZFS ARC cache benefits from available memory
5. **Upgrades follow the release trains** — 24.10 → 24.10.2.4 → 25.04, one train at a time, with a config export first and the previous boot environment kept for rollback
