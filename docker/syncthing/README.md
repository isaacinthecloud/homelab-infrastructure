# Syncthing — Obsidian Vault Sync

## Overview

An Obsidian vault is kept in sync between a Linux laptop, a Windows desktop and a phone. The NAS runs Syncthing as the **always-on hub**, so devices don't need to be online at the same time.

```
Laptop ─┐
Desktop ┼── Syncthing (LXC 103) ── /obsidian ── NFS ── TrueNAS datastore/isaac/Obsidian
Phone  ─┘        :22000 tcp/quic          (daily ZFS snapshots, 4 weeks)
```

## Design

| Decision | Reason |
|---|---|
| Runs as its own container on `traefik-net`, **not** behind Gluetun | Peers must reach it directly on the LAN or over Tailscale |
| Global discovery, relays, NAT traversal and crash reporting **off** | Devices are added by ID with a fixed address (`tcp://10.2.1.x:22000`); nothing leaves the network |
| Vault on NFS, Syncthing database on local disk | Syncthing's database must not live on NFS |
| `ignorePerms` on the folder | The dataset uses NFSv4 ACLs; Syncthing can't apply Unix permissions there |
| Staggered versioning (30 days) + daily ZFS snapshots | Two independent ways to recover an overwritten note |
| `.stignore` for `workspace*.json` and `.obsidian/cache` | Avoids constant churn and conflicts from per-device UI state |
| Web UI only through Traefik (`syncthing.lab.example.com`) | Port 8384 is not published |

Remote devices reach the NAS through the Tailscale subnet router, so sync also works away from home.

## Lessons Learned

The first desktop device pointed at the vault's **parent** directory and synced unrelated files (a `.env`, a Python venv, `.git`). The NAS folder was reset and the device re-added with the correct folder path. Check the folder root on every new device before accepting the share.
