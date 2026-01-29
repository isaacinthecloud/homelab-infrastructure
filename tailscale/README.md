# Tailscale

## Overview

Tailscale runs as LXC 102 on Proxmox, providing secure remote access via a WireGuard mesh VPN without opening any inbound ports.

## Configuration

|Setting|Value|
|---|---|
|Container ID|LXC 102|
|IP Address|10.2.1.x (VLAN 21)|
|Role|Subnet Router|
|Advertised Routes|10.2.1.0/24|

## Why Tailscale?

- **Zero port forwarding** — No inbound firewall rules needed
- **WireGuard-based** — Modern, fast, secure protocol
- **Subnet routing** — Access the entire VLAN 21 from anywhere
- **MagicDNS** — Automatic DNS for Tailscale devices

## Remote Access Flow

1. Remote device connects to Tailscale network
2. Traffic routes through Tailscale's DERP relays (or direct if possible)
3. Reaches LXC 102 subnet router
4. Subnet router forwards traffic to internal services (Traefik, etc.)

## Security Benefits

- No exposed ports on the public IP
- All traffic encrypted end-to-end
- Device-level authentication
- ACLs for granular access control