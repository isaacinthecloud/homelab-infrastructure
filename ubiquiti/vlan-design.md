# VLAN Design

## Overview

The network is segmented into four VLANs to enforce security boundaries and traffic isolation.

## VLAN Architecture

### VLAN 1 - Management
- **CIDR:** 10.2.0.0/24
- **Purpose:** Infrastructure control plane
- **Devices:**
  - Ubiquiti Cloud Gateway Max
  - Ubiquiti U7 Pro AP
  - Network switches
- **Access Policy:** Admin-only, no client devices

### VLAN 21 - Trusted
- **CIDR:** 10.2.1.0/24
- **Purpose:** Trusted internal clients and servers
- **Devices:**
  - Admin workstations
  - Trusted mobile devices
  - Proxmox host
  - All LXC containers (AdGuard, Tailscale, Docker, etc.)
  - TrueNAS VM
- **Access Policy:** Full internal access, VPN access enabled

### VLAN 210 - IoT
- **CIDR:** 10.2.10.0/24
- **Purpose:** Untrusted smart devices
- **Devices:**
  - Smart home devices
  - IoT sensors
  - Media streaming devices
- **Access Policy:** 
  - Internet access allowed
  - No east-west traffic (devices can't talk to each other)
  - No access to Trusted or Management VLANs
  - DNS allowed to AdGuard only

### VLAN 1610 - Guest
- **CIDR:** 192.168.10.0/24
- **Purpose:** Visitor internet access
- **Devices:**
  - Guest phones/laptops
- **Access Policy:**
  - Internet-only
  - No access to any internal networks
  - Client isolation enabled

## Why This Design?

1. **Defense in depth** - Compromised IoT device can't pivot to trusted network
2. **Minimal attack surface** - Each VLAN only has necessary access
3. **Clear trust boundaries** - Easy to audit and explain
4. **Scalable** - Can add more VLANs as needed (e.g., DMZ, Lab)