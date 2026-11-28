# Security

## Overview

This section documents the security architecture, threat model, and network isolation strategies for the homelab.

## Key Security Principles

1. **Defense in depth** - Multiple layers of protection
2. **Least privilege** - Services only access what they need
3. **Network segmentation** - VLANs isolate different trust levels
4. **No inbound ports** - Remote access via Tailscale only

## Threat Model

| Threat             | Mitigation                              |
| ------------------ | --------------------------------------- |
| External attacks   | No port forwarding, Tailscale VPN       |
| IoT compromise     | VLAN 210 isolated, no east-west traffic |
| Guest abuse        | VLAN 1610 internet-only, no LAN access  |
| Service compromise | Container isolation, separate LXCs      |
| DNS poisoning      | AdGuard with DNSSEC                     |

## Network Isolation

Firewall rules enforce strict inter-VLAN access controls on the Ubiquiti Cloud Gateway Max.

**Key Firewall Policies:**
- Management VLAN (1) accessible only from admin devices
- Trusted VLAN (21) has full internal access
- IoT VLAN (210) denied east-west communication between devices
- Guest VLAN (1610) internet-only, no access to internal networks
- All VLANs allowed to query AdGuard DNS (VLAN 21)

## SSL / TLS

All internal services use HTTPS via Traefik with Let's Encrypt certificates.  
Certificates are issued using the DNS-01 challenge through Route53, avoiding the need for inbound HTTP/HTTPS ports.

## Access Hardening

| Area | Control |
|---|---|
| TrueNAS SSH | Key-only login, weak ciphers (AES128-CBC, NONE) disabled, host keys rotated |
| Homelab admin access | One dedicated SSH key, restricted server-side to a single client IP (`from=`) |
| Backup account | SFTP-only NAS user: no shell, no password, `restrict`-ed key, one directory |
| NFS | Each export allows only the Proxmox host; container root is mapped to an ordinary NAS user |
| Hypervisor | Host never touches the NAS disks (controller bound to `vfio-pci` at boot; host ZFS auto-import masked) |

## Secrets Management

- Container secrets live in `/root/docker/.env` (mode 600); the compose file contains only `${VARIABLE}` references
- This repository contains placeholders only (`example.com`, `10.2.1.x`, `.env.example`), and `.gitignore` blocks `.env`, keys and ACME state
- Notification credentials are passed into each system from a root-only file and never written to documentation

## Cloud (AWS) Least Privilege

| IAM identity | Can do |
|---|---|
| Traefik DNS-01 user | Create/delete `_acme-challenge.*` TXT records in one hosted zone, list that zone, poll change status — nothing else ([policy](../docker/traefik/iam-route53-acme.json)) |
| SES SMTP user | `ses:SendRawEmail`, only as the alert address; SES kept in sandbox (200/day, verified recipients only) |
| Off-site uploaders (TrueNAS, Proxmox) | Write only their own S3 prefix, Deep Archive only; no version deletion, no thaw, no bucket changes; auto-blocked at $15/month |
| Temporary setup users | Created per task with a scoped policy, deleted afterwards |

Spend is watched by a $10/month budget and Cost Anomaly Detection (see [monitoring](../monitoring/README.md)).

## Email Authentication

The domain publishes DKIM (Microsoft 365 and SES), SPF and a DMARC policy (`p=quarantine`, `sp=quarantine`, relaxed alignment, aggregate reporting) so alert mail is delivered and the domain is harder to spoof.

## Patch Management

Updates are applied in planned sessions following [docs/maintenance.md](../docs/maintenance.md). Container images are pinned and updated after review; Diun reports new versions weekly.
