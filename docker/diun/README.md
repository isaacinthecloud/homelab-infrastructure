# Diun — Image Update Notifications

## Overview

Every compose image is **pinned to an exact version**, so nothing changes on `docker compose pull` by surprise. [Diun](https://crazymax.dev/diun/) closes the gap that pinning creates: once a week it checks the registries and emails when a newer image exists. Updating stays a deliberate, reviewed step.

| Setting | Value |
|---|---|
| Schedule | Mondays 08:00 (local time) |
| Provider | File (`images.yml`) — **no Docker socket mounted** |
| Notifier | Email via AWS SES (see [monitoring](../../monitoring/README.md)) |
| First run | Records existing tags only (`firstCheckNotif: false`) |

## Two Watch Strategies

| Images | Strategy | Why |
|---|---|---|
| Traefik, Portainer, Gluetun, Bazarr, Syncthing, FlareSolverr, Trailarr, Seerr, Immich, Diun | Watch the repository for **new tags** matching the pinned tag's pattern (e.g. `^v3\.\d+\.\d+$`), newest 10 by semver | Tags sort correctly as versions |
| Radarr, Sonarr, Prowlarr, Lidarr, qBittorrent, Jellyfin | Watch the floating `:latest` tag and alert when its **digest changes** | Four-part / custom tag formats (`6.4.4.10685-ls326`, `12.4ubu2604-ls59`) don't sort as semver — sorting picked years-old tags |

The second row was a lesson learned: after the first scan, every pinned tag was checked against the set Diun was actually watching, and six images were watching ancient tags.

## Files

- [diun.yml](diun.yml) — schedule, defaults, mail notifier (SMTP credentials are read from files, not stored here)
- [images.yml](images.yml) — one entry per pinned image

## Updating an Image After an Alert

```bash
cd /root/docker
# 1. read the release notes, then edit the tag in docker-compose.yml
docker compose pull <service>
docker compose up -d <service>
```

Changing an `image:` line recreates that container even if the image ID is unchanged.
