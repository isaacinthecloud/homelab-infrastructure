# LXC Containers

## Overview

LXC (Linux Containers) provide lightweight OS-level virtualization with lower overhead than full VMs. Three containers run core services, all on Debian 13 "trixie" (upgraded from Debian 12 in November 2026, see the [maintenance runbook](../docs/maintenance.md)).

## Container Summary

| ID  | Name      | vCPU | RAM   | Disk | Type | Purpose           |
| --- | --------- | ---- | ----- | ---- | ---- | ----------------- |
| 101 | adguard   | 1    | 512MB | 8GB  | Unprivileged | DNS Server        |
| 102 | tailscale | 2    | 512MB | 8GB  | Unprivileged | VPN Subnet Router |
| 103 | docker    | 2    | 4GB   | 32GB | Privileged   | Container Host    |

All three start on boot and use the host's time zone.

## LXC 101 — AdGuard Home

**Purpose:** Network-wide DNS server with ad and tracker blocking

**Network Configuration:**
- Interface: eth0 (untagged on VLAN 21)
- IP: Fixed DHCP reservation on the gateway (10.2.1.x/24)
- Gateway: 10.2.1.1

**Key Settings:**
- Unprivileged container
- Nesting + keyctl enabled
- Port 53 (DNS) accessible from all VLANs
- Starts first (order 1) so DNS is available before everything else

## LXC 102 — Tailscale

**Purpose:** Subnet router for remote VPN access

**Network Configuration:**
- Interface: eth0 (untagged on VLAN 21)
- IP: Static (10.2.1.x/24)
- Gateway: 10.2.1.1

**Key Settings:**
- Unprivileged container
- TUN device enabled (`/dev/net/tun`)
- IP forwarding enabled in `/etc/sysctl.d/99-tailscale.conf` (`net.ipv4.ip_forward = 1`). Don't put it in `/etc/sysctl.conf`: Debian 13 no longer reads that file
- Advertises 10.2.1.0/24 subnet

**Special Configuration Required:**
```bash
# In container config (/etc/pve/lxc/102.conf)
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

## LXC 103 — Docker Host

**Purpose:** Runs the whole Docker Compose stack ([docker/](../docker/README.md))

**Network Configuration:**
- Interface: eth0 (untagged on VLAN 21)
- IP: Fixed DHCP reservation (10.2.1.x/24)

**Key Settings:**
- **Privileged** — needed for Docker-in-LXC with bind-mounted NFS data and GPU access
- Nesting enabled
- Starts last (order 4), after TrueNAS is up

**Mounts and devices (`/etc/pve/lxc/103.conf` excerpt):**
```
mp0: /mnt/pve/truenas-data,mp=/data          # media + downloads (NFS on the host)
mp1: /mnt/pve/truenas-obsidian,mp=/obsidian  # Obsidian vault (NFS on the host)
dev0: /dev/dri/renderD128,gid=104            # Intel iGPU for Jellyfin Quick Sync
```

**Inside the container:**
- `/root/docker/docker-compose.yml` + `.env` (mode 600)
- `compose-stack.service` brings the stack up after boot ([why](../docker/systemd/README.md))
- Application configs on the container's local disk (backed up nightly with the container)
