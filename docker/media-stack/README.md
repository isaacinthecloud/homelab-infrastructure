# Media Stack

## Overview

The media stack consists of the ARR suite for automated media management, qBittorrent for downloads, and Jellyfin for media streaming. All download-related traffic is routed through a Gluetun VPN container to enforce network isolation and prevent traffic leaks.

## Components

| Service      | Purpose                         | Port | Network |
|--------------|---------------------------------|------|---------|
| Gluetun      | VPN container (NordVPN, OpenVPN) | -    | traefik-net |
| Radarr       | Movie management                | 7878 | via Gluetun |
| Sonarr       | TV show management              | 8989 | via Gluetun |
| Lidarr       | Music management                | 8686 | via Gluetun |
| Prowlarr     | Indexer management              | 9696 | via Gluetun |
| Bazarr       | Subtitle management             | 6767 | via Gluetun |
| FlareSolverr | Cloudflare challenge solver for Prowlarr | 8191 | via Gluetun |
| qBittorrent  | Torrent client                  | 8080 | via Gluetun |
| Jellyfin     | Media server                    | 8096 | traefik-net (no VPN) |
| Trailarr     | Downloads trailers for Radarr/Sonarr titles | 7889 | traefik-net (no VPN) |
| Seerr        | Media requests (Jellyfin login) → Radarr/Sonarr | 5055 | traefik-net (no VPN) |

## Network Architecture

- All ARR services, FlareSolverr and qBittorrent share Gluetun's network namespace (`network_mode: service:gluetun`)
- Their web UIs are published through Traefik labels on the Gluetun container
- Jellyfin remains on the local network to provide fast, reliable streaming to household devices
- Trailarr also stays off the VPN (YouTube blocks most VPN exit IPs) and reaches Radarr/Sonarr at `http://gluetun:7878` / `http://gluetun:8989`; Seerr does the same and talks to Jellyfin at `http://jellyfin:8096`
- Gluetun kill switch prevents any outbound traffic if the VPN tunnel disconnects
- VPN apps only start once Gluetun reports healthy (`depends_on: condition: service_healthy`)

## Storage Layout

Media and downloads live on **one** TrueNAS dataset (`datastore/data`, 1M recordsize), so imports never cross a filesystem. Lidarr imports as instant hardlinks. Radarr and Sonarr have hardlinks **turned off** (since November 2026) and import a separate copy, so library files can be edited in place, e.g. to rename subtitle tracks, without touching the data qBittorrent is still seeding. That costs double space until a torrent stops seeding and is removed:

```
/data
├── torrents/          # qBittorrent downloads, one folder per category
│   ├── movies/        #   category radarr
│   ├── tv/            #   category tv-sonarr
│   └── music/         #   category lidarr
└── media/             # Libraries the *arr apps import into
    ├── movies/
    ├── tv/
    └── music/
```

| Container | Mount |
|---|---|
| Radarr, Sonarr, Lidarr, Bazarr, qBittorrent | `/data:/data` (same path everywhere, so imports stay on one filesystem) |
| Jellyfin | `/data/media:/data/media:ro` (read-only) |
| Trailarr | `/data/media:/data/media` (read-write: saves `<Title>-trailer.mkv` next to each movie/show, which Jellyfin picks up as a local trailer) |
| All apps | `/config` on the LXC's local disk (SQLite databases are kept off NFS) |

The dataset reaches the containers in two steps: TrueNAS exports it over NFS **to the Proxmox host only**, and the host bind-mounts it into LXC 103 (`mp0: /mnt/pve/truenas-data,mp=/data`). Files are written as a single non-root NAS user (`mapall`), and a guard on the empty mount point prevents writes to local disk if the NFS share is down.

## Quality Profiles

Radarr and Sonarr both have a **Best Available** profile, the default for Seerr requests. The goal is 4K HDR without huge files:

- **Allowed:** HDTV, WEB and Bluray at 1080p and 2160p. Remux, BR-DISK and Raw-HD are disallowed in every profile.
- **Size cap** for Bluray-2160p: 250 MB/min in Radarr, 200 MB/min in Sonarr.
- **Upgrades** until Bluray-2160p **and** a custom format score of 100 (`minFormatScore` 0).

| Custom format | Matches | Score (all profiles) |
|---|---|---|
| HDR | HDR / DV in the release title | +100 (Best Available upgrades until it has it) |
| DV + HDR10+ | Both Dolby Vision and HDR10+ | 0 (kept for reference: Jellyfin won't fall back to HDR10 on these, so they transcode on the TV) |
| Dub only (no Japanese) | English dub tag, not Dual/Multi audio | -1000 (rejected: anime should keep Japanese audio) |
| French | VF / VOSTFR / FRENCH / TRUEFRENCH ... | -1000 (rejected) |

Gotcha: the *arr "Add" dialog has no server-side default profile. It remembers the last one used per browser and otherwise falls back to the first one ("Any", which never upgrades), so check the profile when adding manually.

Lidarr's **Best Available** accepts High Quality Lossy (MP3 V0/320, AAC-320, ...) and Lossless, upgrading until Lossless; it is the music root folder's default.

## Subtitles (Bazarr)

Language profile **English+Spanish** (en, es, es-419) is the default for movies and series. Sources need no accounts: embedded subtitles (already inside the file), Gestdown (TV), YIFY Subtitles (movies), Subtitulamos.tv and Subtis (Spanish). Podnapisi is gone from current Bazarr and TVsubtitles is forced off. OpenSubtitles.com is the best single source but needs a free account.

## Seeding (qBittorrent)

| Setting | Value |
|---|---|
| Share limit | Ratio 1.0 **or** 7 days of seeding (10080 min), whichever comes first, then the torrent is **stopped** |
| Queue | 15 active downloads, 60 active uploads, 75 active torrents; slow torrents don't count toward the limits |
| Excluded file names | Executables, scripts, shortcuts, installers and disk images (`*.exe`, `*.scr`, `*.lnk`, `*.bat`, `*.ps1`, `*.msi`, `*.iso`, ...) are never downloaded |

Radarr and Sonarr have "Remove completed downloads" on, so they delete a torrent once qBittorrent has stopped it; the imported library file stays. The 7-day limit only counts time spent actively seeding, which is why the queue limits are generous: with the original 3 active uploads, queued torrents never aged out.

NordVPN offers no port forwarding, so public swarms are slower than on an open connection.

## Indexers (Prowlarr, public only)

| Indexer | Use | Priority | Notes |
|---|---|---|---|
| SubsPlease | Anime | 10 | |
| Nyaa.si | Anime | 15 | |
| Anime Tosho | Anime | 20 | Aggregates Nyaa, Tokyo Toshokan and others |
| Knaben | General incl. music | 25 | Meta-search over many trackers |
| The Pirate Bay | General | 25 | Via the apibay API |
| 1337x | General | 25 | FlareSolverr |
| EZTV | TV | 25 | FlareSolverr |
| Internet Archive | Public-domain content | 25 | |

Left out on purpose: YTS (heavily compressed encodes and no custom formats to filter them), LimeTorrents / Torrent Downloads / Uindex (mostly duplicates of Knaben, more fakes). Prowlarr syncs everything to Radarr, Sonarr and Lidarr (full sync); a lower priority number wins ties.

## Hardware Transcoding

The Proxmox host's Intel iGPU render node is passed into LXC 103 and then into Jellyfin (`/dev/dri`). Jellyfin uses Intel Quick Sync (QSV) for decode and HEVC encode with VPP tone mapping; an HEVC transcode uses ~20% of one CPU core.

## Lessons Learned

- **Stale VPN server list.** Gluetun's bundled NordVPN server list was over a year old and the tunnel never came up. Fix: persist `/gluetun`, run the updater once, and set `UPDATER_PERIOD=24h`.
- **Start-order race.** See [systemd/README.md](../systemd/README.md).
- **Jellyfin migration crash.** An upgrade left Jellyfin crash-looping on a database migration; the fix was a fresh config. This is one reason images are now pinned and updated deliberately.

## Screenshots

### Portainer Media Stack Overview

![Portainer Dashboard](screenshots/portainer_dashboard.png)

*Portainer dashboard showing the running media stack containers, including Gluetun, ARR services, and Jellyfin.*

### Jellyfin Dashboard

![Jellyfin Dashboard](screenshots/jellyfin_dashboard.png)

*Jellyfin web interface displaying the media libraries, used for local media streaming.*

## Disclaimer

This repository and its documentation are provided **for educational and infrastructure demonstration purposes only**.

- No guidance is provided on acquiring copyrighted material
- The author does **not** condone or support piracy
- All media management and streaming tools shown here are intended for use with **legally obtained content only**

Users are responsible for ensuring compliance with all applicable laws and service terms in their jurisdiction.
