# Security

## Overview

This section documents the security architecture, threat model, and network isolation strategies for the homelab.

## Key Security Principles

1. **Defense in depth** - Multiple layers of protection
2. **Least privilege** - Services only access what they need
3. **Network segmentation** - VLANs isolate different trust levels
4. **No inbound ports** - Remote access via Tailscale only

## Threat Model

| Threat             | Mitigation                              |
| ------------------ | --------------------------------------- |
| External attacks   | No port forwarding, Tailscale VPN       |
| IoT compromise     | VLAN 210 isolated, no east-west traffic |
| Guest abuse        | VLAN 1610 internet-only, no LAN access  |
| Service compromise | Container isolation, separate LXCs      |
| DNS poisoning      | AdGuard with DNSSEC                     |

## Network Isolation

Firewall rules enforce strict inter-VLAN access controls on the Ubiquiti Cloud Gateway Max.

**Key Firewall Policies:**
- Management VLAN (1) accessible only from admin devices
- Trusted VLAN (21) has full internal access
- IoT VLAN (210) denied east-west communication between devices
- Guest VLAN (1610) internet-only, no access to internal networks
- All VLANs allowed to query AdGuard DNS (VLAN 21)

## SSL / TLS

All internal services use HTTPS via Traefik with Let's Encrypt certificates.  
Certificates are issued using the DNS-01 challenge through Route53, avoiding the need for inbound HTTP/HTTPS ports.
