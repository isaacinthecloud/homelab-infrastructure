# Docker Host

## Overview

Docker runs in LXC 103 on Proxmox, hosting all containerized applications including the Traefik reverse proxy, media stack, file sync and supporting services.

## Host Configuration

| Component | Details |
| --------- | ------- |
| LXC ID    | 103 (privileged — needed for NFS bind mounts and GPU access) |
| vCPU      | 2 |
| RAM       | 8 GB |
| Storage   | 32 GB root disk (container configs live here) |
| GPU       | Intel iGPU render node `/dev/dri/renderD128` passed through (Jellyfin + Immich Quick Sync, Immich OpenVINO ML) |
| Mounts    | `/data` (media + downloads), `/obsidian` (vault), `/photos` (Immich library) — NFS from TrueNAS, mounted on the Proxmox host and bind-mounted in |
| Network   | VLAN 21 (10.2.1.x/24), fixed DHCP reservation |
| Boot      | Starts last (startup order 4), after AdGuard, Tailscale and TrueNAS |

## Container Stack

### Core Infrastructure
- **Traefik** — Reverse proxy with automatic SSL ([details](traefik/README.md))
- **Portainer** — Container management UI
- **Diun** — Weekly email when a newer image version exists ([details](diun/README.md))

### Media Stack (via Gluetun VPN)
- **Radarr** — Movie management
- **Sonarr** — TV show management
- **Lidarr** — Music management
- **Prowlarr** — Indexer management
- **Bazarr** — Subtitle management
- **FlareSolverr** — Solves Cloudflare challenges for Prowlarr
- **qBittorrent** — Torrent client

### Media Server
- **Jellyfin** — Media streaming server for local household access, hardware transcoding via Intel Quick Sync
- **Trailarr** — Downloads trailers for Radarr/Sonarr titles as local files for Jellyfin (not via VPN)
- **Seerr** — Request movies and shows with a Jellyfin login; approved requests go to Radarr/Sonarr (not via VPN)

### Photos
- **Immich** — Photo/video library with mobile backup at `photos.lab` (not via VPN). Server, OpenVINO machine learning on the iGPU, Valkey and Postgres; only the server joins `traefik-net`, the rest sit on a private `immich-net`. Library on NFS `datastore/photos` (`/photos`); Postgres on the container's local disk (Immich doesn't support its DB on network shares). DB password in `/root/docker/immich.env` ([example](immich.env.example))

### File Sync
- **Syncthing** — Obsidian vault sync between laptop, desktop and phone, with the NAS as the always-on copy ([details](syncthing/README.md))

## Docker Compose

The homelab is orchestrated using **Docker Compose**, which provides several advantages over running individual containers manually:

1. **Multi-Container Management**
	All services, networks, volumes, and dependencies are defined in a single compose file, so the **entire stack can be started, stopped, or rebuilt consistently** with `docker compose up -d`.
2. **Networking and Isolation**
	Compose defines custom networks (e.g., `traefik-net`) to **control which containers can communicate**. This works alongside Gluetun to ensure media services route traffic through a VPN while the rest of the infrastructure remains on the local network.
3. **Reproducibility and Versioning**
	Every image is **pinned to an exact version tag** (no `:latest`). The compose file documents exactly what runs, and rolling back is a one-line tag change.
4. **Dependency Management**
	VPN-routed services use `depends_on: gluetun: condition: service_healthy`, so they only start once the VPN tunnel is up.
5. **Security**
	- `network_mode: service:gluetun` for VPN isolation
	- `security_opt: no-new-privileges:true`
	- Labels for Traefik routing and HTTPS with TLS certs
	- Secrets only in `.env` (mode 600, git-ignored); the compose file holds `${VARIABLE}` references

### Reference Files

- [docker-compose.yaml](docker-compose.yaml) — sanitized copy of the live compose file
- [.env.example](.env.example) — every variable the compose file expects, with placeholder values
- [systemd/compose-stack.service](systemd/compose-stack.service) — boot-time fix for the Gluetun start-order race ([why](systemd/README.md))

> All secrets, credentials and the real domain are supplied through `.env` and are not in this repository.

## Update Process

Images are updated deliberately, not automatically:

1. Diun emails that a new version exists
2. Read the release notes
3. Edit the tag in `docker-compose.yml`, then `docker compose pull <service> && docker compose up -d <service>`

See [docs/maintenance.md](../docs/maintenance.md) for the full update runbook, including the Docker engine itself.
