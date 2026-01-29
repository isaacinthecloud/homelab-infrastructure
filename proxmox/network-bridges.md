# Network Bridges

## Overview

Proxmox uses Linux bridges to connect virtual machines and containers to the physical network. This setup uses a single physical NIC with VLAN-aware bridging.

## Physical Interface

```
enp4s0
├── State: UP
├── MTU: 1500
├── MAC: 10:7c:61:3f:*
└── Role: Trunk port carrying all VLANs
```

## Bridge Configuration

### vmbr0 — Primary Bridge (VLAN-Aware)

The main bridge that all guests connect to. Configured as VLAN-aware to pass tagged traffic.

```
vmbr0
├── Upstream: enp4s0
├── Mode: VLAN-aware
├── Carries: All VLAN tags (1, 21, 210, 1610)
└── Connected:
    ├── veth101i0 (AdGuard LXC)
    ├── veth102i0 (Tailscale LXC)
    ├── veth103i0 (Docker LXC)
    ├── fwpr100p0 (TrueNAS VM via firewall bridge)
    └── fwpr104p0 (DC01 VM via firewall bridge)
```

**Proxmox `/etc/network/interfaces` excerpt:**

```
auto vmbr0
iface vmbr0 inet manual
    bridge-ports enp4s0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

### vmbr0v21 — Host Management Bridge

A VLAN-specific bridge for Proxmox host management access.

```
vmbr0v21
├── Upstream: enp4s0.21 (802.1Q subinterface)
├── Purpose: Proxmox host management
└── IP: 10.2.1.x/24
```

## Interface Types Explained

|Interface Pattern|Type|Purpose|
|---|---|---|
|`vethXXXi0`|Virtual Ethernet|LXC container network interface|
|`tapXXXi0`|TAP Device|KVM VM network interface|
|`fwbrXXXi0`|Firewall Bridge|VM traffic inspection bridge|
|`fwprXXXp0`|Firewall Port|Bridge port on vmbr0 side|
|`fwlnXXXi0`|Firewall Link|Bridge port on VM side|

## How Traffic Flows

### LXC Container Traffic

```
Container eth0 → vethXXXi0 → vmbr0 → enp4s0 → Physical Network
```

### VM Traffic (with Proxmox Firewall)

```
VM virtio → tapXXXi0 → fwbrXXXi0 → fwlnXXXi0/fwprXXXp0 → vmbr0 → enp4s0
```

The firewall bridge (`fwbr`) allows Proxmox to inspect and filter VM traffic.

## Verifying Configuration

```bash
# Show all interfaces
ip link

# Show bridge members
bridge link show

# Show VLAN configuration
bridge vlan show
```