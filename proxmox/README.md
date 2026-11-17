# Proxmox VE Configuration

## Overview

Proxmox VE serves as the Type-1 hypervisor hosting all virtualized workloads. The host runs on a single physical NIC with VLAN-aware bridging and boots from a local NVMe SSD (LVM-thin for guest disks).

## Host Specifications

| Component | Details |
|-----------|---------|
| Proxmox Version | 9.2.28 (Debian 13 "trixie", kernel 7.0.14) |
| Package repos | `pve-no-subscription`, Debian with `non-free-firmware` (deb822 `.sources` files) |
| CPU microcode | `intel-microcode`, loaded early at boot |
| Hostname | pve |
| Boot / guest storage | NVMe SSD, LVM-thin (`local-lvm`) |
| Physical NIC | enp4s0 (name pinned by MAC, see [Network Bridges](network-bridges.md)) |
| Bridge Mode | VLAN-aware |
| Primary Bridge | vmbr0 |
| iGPU | Intel UHD 730, render node passed to the Docker LXC |

## Workloads

### LXC Containers
| ID | Name | Purpose | VLAN | Boot order |
|----|------|---------|------|------------|
| 101 | adguard | DNS Server / Ad Blocking | 21 | 1 |
| 102 | tailscale | VPN Subnet Router | 21 | 2 |
| 103 | docker | Container Host (Traefik, ARR, Jellyfin, Syncthing) | 21 | 4 |

### Virtual Machines
| ID | Name | Purpose | VLAN | Boot order |
|----|------|---------|------|------------|
| 100 | truenas | ZFS Storage (NFS/SMB/iSCSI/SFTP) | 21 | 3 (+120 s delay) |
| 104 | dc01 | Domain Controller (Lab/Testing) | 21 | manual |

Additional security-lab guests (CT 200, VMs 500–503) are kept powered off and are out of scope for this repository.

### Boot Order

TrueNAS must be fully up before anything mounts its NFS shares. Startup order: AdGuard (DNS) → Tailscale → TrueNAS, then a **120-second delay** → Docker LXC. Without it, NFS mounts timed out at boot and were never retried.

## Storage

| Storage ID | Type | Backed by | Used for |
|---|---|---|---|
| `local` | Directory | NVMe | ISOs, templates, weekly TrueNAS VM backup |
| `local-lvm` | LVM-thin | NVMe | Guest disks |
| `truenas-data` | NFS 4.2 | `datastore/data` | Bind-mounted into LXC 103 as `/data` |
| `truenas-obsidian` | NFS | `datastore/isaac/Obsidian` | Bind-mounted into LXC 103 as `/obsidian` |
| `truenas-photos` | NFS | `datastore/photos` | Bind-mounted into LXC 103 as `/photos` (Immich) |
| `truenas-backups` | NFS | `datastore/backups/proxmox` | Nightly guest backups, host config archives |
| `truenas-offsite` | Directory (inside `truenas-backups`, refuses to write if unmounted) | `datastore/backups/proxmox/offsite` | Weekly core-guest set that TrueNAS uploads to S3 |

NFS shares are mounted **by the host** (as Proxmox storages) and passed into containers as bind mounts. The empty mount-point directories are made immutable (`chattr +i`), so nothing can be written to local disk if a share is missing.

## Contents

- [Network Bridges](network-bridges.md) — vmbr0 and VLAN configuration
- [LXC Containers](lxc-containers.md) — Container setup and networking
- [VM Configuration](vm-config.md) — TrueNAS VM with disk controller passthrough
- Backups — see [backups/README.md](../backups/README.md)
- Alerts — see [monitoring/README.md](../monitoring/README.md)

## Key Design Decisions

1. **Single NIC with VLAN trunk** — Simplifies cabling; all VLANs carried on one link
2. **LXC for lightweight services** — Lower overhead than full VMs for AdGuard, Tailscale, and Docker
3. **VM for TrueNAS** — Requires PCIe passthrough for the disk controller
4. **All workloads on VLAN 21** — Trusted network for internal services
5. **Host mounts NFS, containers get bind mounts** — One place to manage mounts; containers never need NFS client privileges
