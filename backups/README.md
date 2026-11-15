# Backups

## Overview

Backups are layered so that each common failure has a recovery path that doesn't depend on the thing that failed.

| Layer | What | Where | Schedule | Retention |
|---|---|---|---|---|
| Guest backups | LXC 101/102/103 + lab guests (`vzdump`, snapshot mode, zstd) | TrueNAS `datastore/backups/proxmox` (NFS) | Nightly 02:30 | 7 daily, 4 weekly, 6 monthly |
| TrueNAS VM | VM 100 boot disk (data disks are passed through and excluded) | Proxmox host NVMe (`local`) — **not** onto TrueNAS itself | Weekly, Sunday 03:30 | Last 2 |
| Proxmox host config | `/etc` (incl. `/etc/pve`, network, storage) + root's SSH keys | TrueNAS `backups/proxmox/host` | Weekly (cron) | Last 8 |
| NAS data | ZFS snapshots of `isaac`, `NAS`, `backups/laptop` | Same pool | Daily / weekly | 4 weeks |
| Laptop | `/` and `/home` via restic | TrueNAS `datastore/backups/laptop` (SFTP) | Daily | 7 daily, 4 weekly, 6 monthly |
| TrueNAS config | Config export incl. secret seed | `backups/truenas-config/` + offline copy before upgrades | Weekly (Sun 05:00) | Last 8 |
| **Off-site** | Encrypted copies of all of the above + the iSCSI zvol | AWS S3 Glacier Deep Archive | Daily / weekly / monthly | 180 days of history |

Backup failures email an alert (see [monitoring](../monitoring/README.md)). Off-site design, encryption, cost controls and restore steps: **[offsite/README.md](offsite/README.md)**.

## Proxmox Guest Backups

Configured as two Proxmox backup jobs:

```
vzdump: nightly-nas
        schedule 02:30
        storage truenas-backups
        mode snapshot
        compress zstd
        vmid 101,102,103,104,200,500,501,502,503
        prune-backups keep-daily=7,keep-weekly=4,keep-monthly=6

vzdump: weekly-truenas
        schedule sun 03:30
        storage local
        vmid 100
        prune-backups keep-last=2

vzdump: weekly-offsite
        schedule sun 04:00
        storage truenas-offsite        # uploaded to S3 by TrueNAS Cloud Sync
        vmid 101,102,103
```

**Why TrueNAS is backed up to the host, not to itself:** if TrueNAS is the thing that breaks, its backup must be reachable without it. Its data disks are passed-through hardware, so `vzdump` only captures the 20GB boot disk; the pool itself is protected by RAIDZ1, snapshots and scrubs.

LXC 103's NFS bind mounts (`/data`, `/obsidian`) are excluded from its backup automatically, so the nightly job captures the container OS and app configs, not the media library.

## Proxmox Host Config

[`pve-host-config-backup`](pve-host-config-backup) runs from `/etc/cron.weekly/`. It refuses to run if the NAS storage isn't mounted (so it never fills the host disk) and keeps the newest 8 archives. Cron output is forwarded to email by Proxmox's notification system.

## Laptop Backup (restic over SFTP)

A Linux laptop (btrfs, Omarchy) backs up to the NAS. Omarchy's own snapper snapshots only cover `/`, only around updates, and live on the same disk — fine for rolling back a bad update, useless if the SSD dies or the laptop is lost.

### How it works

1. Takes temporary **read-only btrfs snapshots** of `/` and `/home`, so the backup is a consistent point in time
2. `restic backup` of both snapshots to an encrypted repository on TrueNAS over SFTP, skipping caches (`--exclude-caches` + [excludes](laptop/excludes))
3. `restic forget` keeps 7 daily, 4 weekly, 6 monthly
4. Weekly: `prune` + `check --read-data-subset=5%` (verifies real data, not just metadata)
5. Deletes the temporary snapshots (also on failure)

### When it runs

- [`laptop-backup.timer`](laptop/laptop-backup.timer) fires hourly; the [script](laptop/laptop-backup) only does real work if the last success is ≥ 20 h old, so sleep, travel and NAS downtime are simply retried
- A [NetworkManager hook](laptop/60-laptop-backup-on-home-lan) starts it as soon as the laptop joins the home LAN
- Away from home it runs over Tailscale. The **first** full backup (~19 GiB read, 9 GiB stored) only runs on the home LAN — over a high-latency VPN path SFTP managed ~60 KB/s versus ~23 MiB/s at home
- If the NAS is unreachable it skips quietly; real failures raise a desktop notification ([notify unit](laptop/laptop-backup-notify.service))

### Security

- Repository is encrypted by restic; the password lives in `/etc/restic/password` (root-only) **and in a password manager** — without it the backups are unrecoverable
- The NAS account is SFTP-only: no shell, no password, `restrict`-ed SSH key, one directory
- The NAS host key is pinned (`StrictHostKeyChecking=yes` with a dedicated `known_hosts`)
- Daily ZFS snapshots of the repository dataset mean even a compromised laptop that deletes its backups can't destroy the last 4 weeks

### Restore

```bash
source /etc/restic/env
restic -o "sftp.command=$SFTP_CMD" snapshots
restic -o "sftp.command=$SFTP_CMD" restore latest --target /tmp/restore \
  --include /.laptop-backup-snap/home/<user>/Documents
```

Paths in the repository are under `/.laptop-backup-snap/{root,home}/`.

### Lessons Learned

- A run interrupted mid-backup left a stale **exclusive lock** in the repository, and the next run's `forget` failed. The script now runs `restic unlock` (removes only stale locks) before each backup; a local `flock` already prevents overlapping runs.

## Known Gaps

- Restores are tested ad hoc, not on a schedule. Off-site restores need a Deep Archive thaw (~12–48 h).
- The Windows PC's zvol is copied crash-consistent (snapshot of a live iSCSI disk), not application-consistent.
