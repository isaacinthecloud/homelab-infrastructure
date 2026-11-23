# Home Assistant

## Overview

Home Assistant OS runs as its own VM (105) on Proxmox, **dual-homed**: one NIC on the trusted VLAN for the UI and the reverse proxy, one on the IoT VLAN to reach smart plugs and lights. It is deliberately **not** part of the Docker LXC's compose stack: giving that container a leg on the IoT VLAN would expose every service in it to untrusted devices.

Status: set up in November 2026. Onboarding, integrations (Govee LAN, TP-Link Kasa) and backups to TrueNAS are still in progress. The first goal is a sunrise wake-up automation.

## VM 105

| Setting | Value |
|---|---|
| OS | Home Assistant OS 18.4 (generic x86-64 image; 18.5 was published for Raspberry Pi only) |
| Machine / BIOS | q35, OVMF (UEFI), Secure Boot off (`pre-enrolled-keys=0`) |
| CPU / RAM | 2 cores, 2 GB |
| Disk | 32 GB on `local-lvm`, `discard=on`, `ssd=1` |
| Start on boot | Yes |
| QEMU guest agent | Enabled (used for `qm guest exec` maintenance) |
| `net0` | vmbr0, untagged (trusted VLAN 21), DHCP with a fixed lease in UniFi, Proxmox firewall **off** |
| `net1` | vmbr0, `tag=210` (IoT), static `10.2.10.x/24` with **no gateway**, Proxmox firewall **on** |

The IoT NIC has no default gateway on purpose: HA only needs to talk to devices on the same subnet, and all of its outbound traffic (updates, cloud integrations) leaves through the trusted NIC. The address was set from the host with `qm guest exec 105 -- docker exec hassio_cli ha network update ...`.

## Network Prerequisites

- **VLAN-aware bridge:** `vmbr0` has `bridge-vlan-aware yes` and `bridge-vids 2-4094` (see [Network Bridges](../proxmox/network-bridges.md)). It was applied with a `systemd-run` rollback timer that would have restored the old `/etc/network/interfaces` if the host had become unreachable.
- **Switch port:** the UniFi port profile for the Proxmox host carries the trusted VLAN untagged and all other VLANs tagged.
- **IoT network:** VLAN 210, `10.2.10.0/24`, UniFi "Isolate Network" on. The IoT Wi-Fi is 2.4 GHz with client isolation and multicast filtering **off**, because the device discovery protocols need broadcast and multicast.

## Firewall

Proxmox's datacenter firewall is enabled, with permissive defaults so nothing else changes:

```ini
# /etc/pve/firewall/cluster.fw
[OPTIONS]
enable: 1
policy_in: ACCEPT
policy_out: ACCEPT
```

Only NICs with `firewall=1` **and** a guest `.fw` file are filtered. The only one today is VM 105's IoT NIC:

```ini
# /etc/pve/firewall/105.fw
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT
dhcp: 1
macfilter: 1

[RULES]
IN ACCEPT -i net1 -p udp -dport 4002 -log nolog # Govee LAN API replies
IN ACCEPT -i net1 -p udp -sport 9999 -log nolog # Kasa (legacy) discovery replies
IN ACCEPT -i net1 -p udp -sport 20002 -log nolog # Kasa (KLAP) discovery replies
```

IoT devices can't open connections to HA. HA's own outbound connections and their replies are allowed by connection tracking. The explicit rules cover the UDP replies that conntrack can't match: the devices answer a broadcast from their own address.

Rollback: delete `cluster.fw` and run `pve-firewall restart`.

## Reverse Proxy

HA is published at `ha.lab.<domain>` through Traefik's file provider ([external-services.yml](../docker/traefik/dynamic/external-services.yml)). Two things were not obvious:

- **Port 80, not 8123.** On current HAOS the UI is served on port 80, and port 8123 only answers with a 307 redirect to port 80. Proxying to 8123 produces a redirect loop.
- **The `http:` settings live in the UI.** HA 2026.11 moved them to `.storage/http` at first boot, so an `http:` block in `configuration.yaml` is silently ignored. Set them under **Settings > System > Network > HTTP server**: trust `X-Forwarded-For` on, trusted proxy = the Docker LXC's address (`/32`).

## Updates

HAOS updates itself (OS, Supervisor and Core) from its own UI, so it isn't watched by Diun.
