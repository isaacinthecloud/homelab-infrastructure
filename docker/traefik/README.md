# Traefik Reverse Proxy

## Overview

Traefik provides a reverse proxy with automatic SSL certificates via Let's Encrypt using the DNS-01 challenge through AWS Route53.

## Why Traefik + DNS-01?

1. **No public ports** — DNS-01 does not require ports 80/443 to be exposed to the internet
2. **Wildcard-style naming** — Every service gets a name under `*.lab.example.com`, which resolves to the Docker host's LAN IP
3. **Docker integration** — Automatically discovers containers using Docker labels
4. **Works behind NAT** — Ideal for homelabs without port forwarding (this network is double-NAT)

## Architecture

```
Remote Client → Tailscale VPN → Traefik (:443) → Internal Service
│
└── Let's Encrypt (DNS-01 via Route53)
```

## Configuration

- [traefik.yml](traefik.yaml) — Static configuration (entrypoints, providers, logging, ACME)
- [dynamic/external-services.yml](dynamic/external-services.yml) — Routes for non-container services (Proxmox, TrueNAS, AdGuard), so their web UIs also get trusted certificates
- Container routes are defined as labels in [docker-compose.yaml](../docker-compose.yaml)

All sensitive values have been sanitized for inclusion in this repository.

## Lessons Learned

- **Disable the local propagation check.** Internal DNS (AdGuard) never sees the public `_acme-challenge` TXT record, so Traefik waited forever. `propagation.disableChecks: true` with a fixed 60 s delay fixed issuance.
- **Docker 29 raised the minimum Docker API version.** Older Traefik releases fail to talk to the Docker socket after a Docker engine upgrade. Traefik is now pinned to a release that supports it and updated deliberately.

## Security Highlights

- Dashboard behind basic auth (bcrypt hash supplied from `.env`), not exposed publicly
- HTTPS enforced with automatic HTTP → HTTPS redirects
- No public port exposure required
- Certificates automatically renewed via DNS challenge
- The Route53 IAM user can only read zones and change DNS records — no other AWS access
