# LXC Containers

## Overview

LXC (Linux Containers) provide lightweight OS-level virtualization with lower overhead than full VMs. Three containers run core services.

## Container Summary

| ID  | Name      | vCPU | RAM   | Disk | Purpose           |
| --- | --------- | ---- | ----- | ---- | ----------------- |
| 101 | adguard   | 1    | 512MB | 8GB  | DNS Server        |
| 102 | tailscale | 2    | 512MB | 8GB  | VPN Subnet Router |
| 103 | docker    | 2    | 8GB   | 16GB | Container Host    |

## LXC 101 — AdGuard Home

**Purpose:** Network-wide DNS server with ad and tracker blocking

**Network Configuration:**
- Interface: eth0 (untagged on VLAN 21)
- IP: Static (10.2.1.x/24)
- Gateway: 10.2.1.1

**Key Settings:**
- Unprivileged container
- Nesting disabled
- Port 53 (DNS) accessible from all VLANs

## LXC 102 — Tailscale

**Purpose:** Subnet router for remote VPN access

**Network Configuration:**
- Interface: eth0 (untagged on VLAN 21)
- IP: DHCP (10.2.1.x/24)
- Gateway: 10.2.1.1

**Key Settings:**
- Unprivileged container
- TUN device enabled (`/dev/net/tun`)
- IP forwarding enabled
- Advertises 10.2.1.0/24 subnet

**Special Configuration Required:**
```bash
# In container config (/etc/pve/lxc/102.conf)
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
