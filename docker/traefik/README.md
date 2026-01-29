# Traefik Reverse Proxy

## Overview

Traefik provides a reverse proxy with automatic SSL certificates via Let's Encrypt using the DNS-01 challenge through AWS Route53.

## Why Traefik + DNS-01?

1. **No public ports** — DNS-01 does not require ports 80/443 to be exposed to the internet
2. **Wildcard certificates** — Supports certificates such as `*.lab.example.com`
3. **Docker integration** — Automatically discovers containers using Docker labels
4. **Works behind NAT** — Ideal for homelabs without port forwarding

## Architecture

```
Remote Client → Tailscale VPN → Traefik (:443) → Internal Service  
│  
└── Let's Encrypt (DNS-01 via Route53)
```

## Configuration

Traefik is configured using a static configuration file:

- [traefik.yml](traefik.yml) — Core Traefik configuration (entrypoints, providers, logging, ACME)

All sensitive values have been sanitized for inclusion in this repository.

## Security Highlights

- Dashboard enabled but not exposed publicly
- HTTPS enforced with automatic HTTP → HTTPS redirects
- No public port exposure required
- Certificates automatically renewed via DNS challenge
