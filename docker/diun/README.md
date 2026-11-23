# Diun — Image Update Notifications

## Overview

Every compose image is **pinned to an exact version**, so nothing changes on `docker compose pull` by surprise. [Diun](https://crazymax.dev/diun/) closes the gap that pinning creates: once a week it checks the registries and emails when a newer image exists. Updating stays a deliberate, reviewed step.

| Setting | Value |
|---|---|
| Schedule | Mondays 08:00 (local time) |
| Provider | File (`images.yml`) — **no Docker socket mounted** |
| Notifier | Email via AWS SES (see [monitoring](../../monitoring/README.md)) |
| First run | Records existing tags only (`firstCheckNotif: false`), but see [Adding an Image](#adding-an-image) |

## Two Watch Strategies

| Images | Strategy | Why |
|---|---|---|
| Traefik, Portainer, Gluetun, Bazarr, Syncthing, FlareSolverr, Trailarr, Seerr, Immich, Diun | Watch the repository for **new tags** matching the pinned tag's pattern (e.g. `^v3\.\d+\.\d+$`), newest 10 by semver | Tags sort correctly as versions |
| Radarr, Sonarr, Prowlarr, Lidarr, qBittorrent, Jellyfin | Watch the floating `:latest` tag and alert when its **digest changes** | Four-part / custom tag formats (`6.4.4.10685-ls326`, `12.4ubu2604-ls59`) don't sort as semver — sorting picked years-old tags |

The second row was a lesson learned: after the first scan, every pinned tag was checked against the set Diun was actually watching, and six images were watching ancient tags.

## Adding an Image

`firstCheckNotif: false` does **not** reliably silence a newly added repo-watched image. Diun decides "first check?" separately for each tag job when the job is created, and the jobs run in parallel. If the configured `:latest` job saves its manifest before the other tag jobs are created, those jobs are no longer a first check and each one emails as "new". This is how adding Trailarr, Seerr and Immich produced about 40 alert emails on 2026-11-23 (Diun 4.33.1; 4.34.0 computes it the same way).

To add an image without the flood:

1. Add the entry with `notify_on: [unchange]` (plus its `include_tags`), and the service to `docker-compose.yml` as usual. Diun `from` must be a bare address.
2. Restart Diun (`docker compose restart diun`; `runOnStartup: true` runs a check). Wait for `Jobs completed` in `docker logs diun`. Every existing tag is now recorded with status `new`, which isn't in `notify_on`, so nothing is sent.
3. Change the entry to the normal `notify_on` (omit it for repo-watched images, which use the default `[new]`; `:latest` entries use `[update]`) and restart Diun again. Existing tags are now `unchange` and stay silent; only real new tags alert from here on.

Don't leave an entry on `[unchange]`: it would email for every recorded tag on every run.

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
