# Ubiquiti Network Configuration

## Overview

This section documents the Ubiquiti network infrastructure that forms the foundation of the homelab network.

## Hardware

- **Ubiquiti Cloud Gateway Max** - Router, firewall, VLAN gateway, DHCP server
- **Ubiquiti U7 Pro AP** - Wireless access point with multi-SSID VLAN mapping

## VLAN Design

| VLAN ID | Name | CIDR | Purpose |
|---------|------|------|---------|
| 1 | Management | 10.2.0.0/24 | Infrastructure control plane (Ubiquiti devices) |
| 21 | Trusted | 10.2.1.0/24 | Workstations, admin devices, servers |
| 210 | IoT | 10.2.10.0/24 | Smart devices, restricted east-west traffic |
| 1610 | Guest | 192.168.10.0/24 | Visitor devices, internet-only access |


## Key Design Decisions

1. **VLAN 1 for Management** - Keeps infrastructure traffic isolated
2. **Separate IoT VLAN** - Untrusted devices can't reach trusted network
3. **Guest VLAN with no LAN access** - Internet-only for visitors
4. **SSID-to-VLAN mapping** - Each wireless network maps to appropriate VLAN
