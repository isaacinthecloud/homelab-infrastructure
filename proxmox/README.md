# Proxmox VE Configuration

## Overview

Proxmox VE serves as the Type-1 hypervisor hosting all virtualized workloads. The host runs on a single physical NIC with VLAN-aware bridging.

## Host Specifications

| Component | Details |
|-----------|---------|
| Proxmox Version | 8.4.1 |
| Hostname | pve |
| Physical NIC | enp4s0 |
| Bridge Mode | VLAN-aware |
| Primary Bridge | vmbr0 |

## Workloads

### LXC Containers
| ID | Name | Purpose | VLAN |
|----|------|---------|------|
| 101 | adguard | DNS Server / Ad Blocking | 21 |
| 102 | tailscale | VPN Subnet Router | 21 |
| 103 | docker | Container Host (Traefik, ARR, Jellyfin) | 21 |

### Virtual Machines
| ID | Name | Purpose | VLAN |
|----|------|---------|------|
| 100 | truenas | ZFS Storage (NFS/SMB) | 21 |
| 104 | dc01 | Domain Controller (Lab/Testing) | 21 |

## Contents

- [Network Bridges](network-bridges.md) — vmbr0 and VLAN configuration
- [LXC Containers](lxc-containers.md) — Container setup and networking
- [VM Configuration](vm-config.md) — TrueNAS VM with disk passthrough

## Key Design Decisions

1. **Single NIC with VLAN trunk** — Simplifies cabling; all VLANs carried on one link
2. **LXC for lightweight services** — Lower overhead than full VMs for AdGuard, Tailscale, and Docker
3. **VM for TrueNAS** — Requires PCIe passthrough for the disk controller
4. **All workloads on VLAN 21** — Trusted network for internal services
