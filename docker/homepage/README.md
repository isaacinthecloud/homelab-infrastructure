# Homepage

[Homepage](https://gethomepage.dev) is the lab dashboard, served at `home.lab.example.com`. It uses a blurred wallpaper at half brightness, the dark slate theme, one row-style group per area with 4 columns, equal-height cards, and CPU/RAM/disk plus a clock in the top bar.

## Layout

| Group | Cards (live widget data) |
| ----- | ------------------------ |
| Infrastructure | Proxmox (VMs/LXCs, CPU, RAM), TrueNAS (load, alerts, pool usage), Portainer (containers), Traefik (routers/services) |
| Network | UniFi (WAN, clients), AdGuard Home (queries/blocked), Tailscale (subnet router status), Gluetun (container status + stats) |
| Media | Jellyfin (library counts, now playing), Seerr (requests), Immich (photos/videos/storage), Trailarr (status) |
| Downloads | Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, qBittorrent |
| Home | Home Assistant, Syncthing |

## Design

- **No raw docker.sock.** Container status comes from `homepage-socket-proxy` (linuxserver/socket-proxy, `CONTAINERS=1`, `POST=0`, read-only root filesystem). The proxy sits on a private `homepage-net` that only Homepage joins.
- **No LAN IPs or domain in the config.** `{{HOMEPAGE_VAR_DOMAIN}}` is filled in from compose `${DOMAIN}`. Hosts outside CT 103 are reached through their Traefik names. Docker apps are reached by container name, and the VPN'd apps as `gluetun:<port>` because they share gluetun's network namespace.
- **Secrets** live only in `/root/docker/homepage.env` (mode 600), using the format in [homepage.env.example](homepage.env.example). Every key is read-only where the app supports that: a Proxmox token with PVEAuditor, and a TrueNAS key for a Read-Only Administrator. AdGuard and the Traefik dashboard only have a single admin login.
- `HOMEPAGE_ALLOWED_HOSTS=home.lab.${DOMAIN}`. Without it, Homepage refuses requests whose host it doesn't know.

## Files

- `config/` is mounted at `/root/docker/homepage/config` on CT 103.
- The services are in [docker-compose.yaml](../docker-compose.yaml) (`homepage`, `homepage-socket-proxy`, network `homepage-net`).
- Diun watches `ghcr.io/gethomepage/homepage` (`^v2\.\d+\.\d+$`) and `lscr.io/linuxserver/socket-proxy` (`^\d+\.\d+\.\d+-r\d+-ls\d+$`).

## Changing it

Homepage re-reads YAML on page load, so config edits only need a browser refresh. Changes to `homepage.env` need `docker compose up -d --force-recreate homepage`.

To set or rotate a key, run [set-key.sh](set-key.sh) from `/root/docker`, e.g. `./homepage/set-key.sh TAILSCALE_KEY`. It shows the pasted value, so stray keypresses are visible. It rejects empty values and control characters, writes the line in `homepage.env`, and restarts Homepage.

## Gotchas

- **A widget with a wrong or empty key can get Docker banned.** Home Assistant's IP ban and AdGuard's login lockout both see every request through Traefik as coming from `172.19.0.1`, the gateway of `traefik-net`. Close the dashboard while a key is missing. To lift an HA ban, remove the entry from `ip_bans.yaml` in the HA config and restart HA Core.
- **Home Assistant**: the widget uses `/api/template`, which is admin-only, so the token's HA user must be an administrator.
- **TrueNAS 25.04** answers REST calls made with an API key with 403, so the widget uses `version: 2` (websocket API).
- **Portainer**: `env` is the environment's id (`GET /api/endpoints`), which isn't necessarily 1.
- **Tailscale**: API access tokens expire after at most 90 days. Generate a new one and run `set-key.sh TAILSCALE_KEY`.
