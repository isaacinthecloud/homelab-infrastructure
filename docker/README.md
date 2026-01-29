# Docker Host

## Overview

Docker runs in LXC 103 on Proxmox, hosting all containerized applications including the Traefik reverse proxy, media stack, and supporting services.

## Host Configuration

| Component | Details               |
| --------- | --------------------- |
| LXC ID    | 103                   |
| vCPU      | 2                     |
| RAM       | 2 GB                  |
| Storage   | 16 GB                 |
| Network   | VLAN 21 (10.2.1.x/24) |

## Container Stack

### Core Infrastructure
- **Traefik** — Reverse proxy with automatic SSL
- **Portainer** — Container management UI

### Media Stack (via Gluetun VPN)
- **Radarr** — Movie management
- **Sonarr** — TV show management
- **Lidarr** — Music management
- **Prowlarr** — Indexer management
- **Bazarr** — Subtitle management
- **qBittorrent** — Torrent client

### Media Server
- **Jellyfin** — Media streaming server for local household access

## Docker Compose

The homelab is orchestrated using **Docker Compose**, which provides several advantages over running individual containers manually:

1. **Multi-Container Management**  
	Docker Compose allows defining all services, networks, volumes, and dependencies in a single `docker-compose.yml` file. This ensures the **entire stack can be started, stopped, or rebuilt consistently** with a single command: `docker-compose up -d`
2. **Networking and Isolation**  
	Compose defines custom networks (e.g., `traefik-net`) to **control which containers can communicate**. This works alongside Gluetun to ensure media services route traffic through a VPN while the rest of the infrastructure remains on the local network.
3. **Reproducibility and Versioning**  
    All containers, images, and configuration paths are versioned in the compose file. This makes the stack **easy to replicate**, update, or restore after maintenance.
4. **Dependency Management**  
    Services like Radarr, Sonarr, and qBittorrent are defined to depend on Gluetun. Compose ensures that containers start in the correct order, avoiding network or service errors.
5. **Security**  
    Compose supports features like:
    - `network_mode: service:gluetun` for VPN isolation
    - `security_opt: no-new-privileges:true`
    - Labels for Traefik routing and HTTPS with TLS certs

### Reference File

The **sanitized Docker Compose file** used for this stack is included in the repository:

[docker-compose.yml](docker-compose.yml)

> This file is safe for educational purposes: all secrets, credentials, and domains have been replaced with placeholders. It demonstrates best practices for multi-container orchestration, network isolation, and VPN routing in a homelab environment.