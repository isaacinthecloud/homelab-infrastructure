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

## Client Notes: Laptop on the Home LAN

The laptop accepts the advertised subnet route (`10.2.1.0/24`) so it can reach the homelab from anywhere. At home, that same route sends LAN traffic through Tailscale instead of straight over Wi-Fi, which broke latency-sensitive apps (remote desktop) and slowed transfers.

Fix: a NetworkManager dispatcher hook adds a higher-priority routing rule **only while the laptop has a 10.2.1.x address**:

```sh
# /etc/NetworkManager/dispatcher.d/50-home-lan-bypass-tailscale (excerpt)
ip rule add to 10.2.1.0/24 lookup main priority 5200   # on the home LAN
ip rule del to 10.2.1.0/24 lookup main priority 5200   # elsewhere
```

Away from home the rule is removed and the subnet route works normally. Check with `ip route get 10.2.1.x` (should show the Wi-Fi interface at home, `tailscale0` elsewhere).

## Known Limitation

The home network is double-NAT (ISP modem → Ubiquiti gateway). Remote clients that also run a commercial VPN can end up on a high-latency path (~300 ms). Fine for web UIs and small transfers; large transfers (like a first full backup) are scheduled for when the client is on the LAN.
