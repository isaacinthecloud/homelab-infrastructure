# NFS / SMB / iSCSI / SFTP Shares

## Overview

TrueNAS provides storage to the Proxmox host over NFS, to Windows and Linux clients over SMB, to one Windows PC as an iSCSI block device, and to a laptop backup job over SFTP.

## NFS Shares

NFS is **only exported to the Proxmox host**. The host mounts each share as a Proxmox storage and bind-mounts it into containers, so containers never mount NFS themselves.

### Share Configuration

|Share Path|Allowed Host|Access mapping|Consumer|
|---|---|---|---|
|`/mnt/datastore/data`|Proxmox host only|mapall → NAS user (UID 3000)|LXC 103 `/data` (media + downloads)|
|`/mnt/datastore/isaac/Obsidian`|Proxmox host only|mapall → NAS user (UID 3000)|LXC 103 `/obsidian` (Syncthing)|
|`/mnt/datastore/photos`|Proxmox host only|mapall → NAS user (UID 3000)|LXC 103 `/photos` (Immich)|
|`/mnt/datastore/backups/proxmox`|Proxmox host only|maproot → root|Proxmox backup storage|

### Why mapall?

The containers run their apps as root (PUID 0). Mapping every NFS request to one ordinary NAS user means:

- files on the NAS are owned by a normal user, not root
- the same files are readable over SMB by that user
- a compromised container can't create root-owned files on the NAS

The backup share is the exception: `vzdump` needs root on the target.

## Client Mount Configuration

On the Proxmox host, shares are defined as storages (`/etc/pve/storage.cfg`), not `/etc/fstab` entries:

```
nfs: truenas-data
        export /mnt/datastore/data
        path /mnt/pve/truenas-data
        server 10.2.1.x
        options vers=4.2
        content snippets

nfs: truenas-backups
        export /mnt/datastore/backups/proxmox
        path /mnt/pve/truenas-backups
        server 10.2.1.x
        content backup
```

Proxmox retries storage mounts on its own, which fixed the original problem: `/etc/fstab` NFS entries timed out at boot (TrueNAS was still starting) and were never retried.

The containers get bind mounts (`mp0: /mnt/pve/truenas-data,mp=/data`). The empty mount-point directories on the host are made immutable (`chattr +i`), so if a share is ever missing, writes fail instead of silently filling the host's disk.

## SMB Shares

|Share Name|Path|Access|
|---|---|---|
|isaac|`/mnt/datastore/isaac`|Personal share (laptop mounts it via CIFS)|
|mio|`/mnt/datastore/mio`|Second household member|

## iSCSI

| Extent | Backing | Consumer |
|---|---|---|
| `nas` | zvol `datastore/NAS/nas` (2TB) | Windows PC network drive |

## SFTP (Laptop Backups)

A dedicated `laptop-backup` user owns `datastore/backups/laptop` (mode 700). It has no shell (`nologin`), no password, and its only SSH key carries the `restrict` option. TrueNAS's SFTP server runs inside sshd (`internal-sftp`), so file transfer works while shell login is refused. See [backups/README.md](../backups/README.md).

## Security Considerations

1. **Hypervisor-only NFS** — Each NFS export allows exactly one host
2. **No internet exposure** — NFS/SMB/iSCSI never exposed to WAN
3. **Non-root mapping** — Container root becomes an ordinary NAS user
4. **Least-privilege backup account** — SFTP only, single directory, snapshots protect it from deletion
