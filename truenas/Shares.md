# NFS/SMB Shares

## Overview

TrueNAS provides centralized storage to the Docker LXC via NFS. SMB shares are available for Windows clients if needed.

## NFS Shares

NFS is used for Linux-to-Linux communication (Docker LXC → TrueNAS).

### Share Configuration

|Share Path|Allowed Networks|Maproot User|Maproot Group|
|---|---|---|---|
|/mnt/tank/appdata|10.2.1.0/24|root|root|
|/mnt/tank/media/movies|10.2.1.0/24|root|root|
|/mnt/tank/media/tv|10.2.1.0/24|root|root|
|/mnt/tank/media/music|10.2.1.0/24|root|root|
|/mnt/tank/downloads|10.2.1.0/24|root|root|

### NFS Settings

|Setting|Value|Reason|
|---|---|---|
|NFS Version|NFSv4|Modern, better performance|
|Allowed Networks|10.2.1.0/24|Trusted VLAN only|
|Maproot User|root|Docker containers run as root|

## Client Mount Configuration

On Docker LXC (`/etc/fstab`):

```
# TrueNAS NFS Mounts
10.2.1.x:/mnt/tank/appdata/radarr    /mnt/truenas/Config/radarr    nfs defaults,_netdev 0 0
10.2.1.x:/mnt/tank/appdata/sonarr    /mnt/truenas/Config/sonarr    nfs defaults,_netdev 0 0
10.2.1.x:/mnt/tank/media/movies      /mnt/truenas/Movies           nfs defaults,_netdev 0 0
10.2.1.x:/mnt/tank/media/tv          /mnt/truenas/TV_Shows         nfs defaults,_netdev 0 0
10.2.1.x:/mnt/tank/media/music       /mnt/truenas/Music            nfs defaults,_netdev 0 0
10.2.1.x:/mnt/tank/downloads         /mnt/truenas/Downloads        nfs defaults,_netdev 0 0
```

### Mount Options Explained

- `defaults` — Standard mount options
- `_netdev` — Wait for network before mounting (important for boot)

## SMB Shares (Optional)

SMB shares for Windows client access if needed.

|Share Name|Path|Access|
|---|---|---|
|Media|/mnt/tank/media|Read-only|
|Downloads|/mnt/tank/downloads|Read-write|

## Security Considerations

1. **Network restriction** — Shares only accessible from Trusted VLAN
2. **No internet exposure** — NFS/SMB never exposed to WAN
3. **Root mapping** — Used because Docker containers run as root
4. **Firewall rules** — Only Docker LXC IP can access NFS