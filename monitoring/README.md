# Alerting & Notifications

## Overview

Every system that can fail silently now sends email to one shared mailbox. Mail goes out through **AWS SES** using a send-only credential, so no server needs a personal mailbox password.

```
TrueNAS alerts ─┐
Proxmox notifs ─┼─ SMTP (587, STARTTLS) ─ AWS SES ─ alerts@example.com (shared mailbox)
Diun (images)  ─┘
AWS Budgets / Cost Anomaly Detection ──────────────┘
```

## Why SES?

Proxmox's default notification target sent mail directly from the host to the admin's Gmail. Every message bounced (`550 5.7.26 … sender is unauthenticated`) because a home IP can't pass SPF/DKIM — so **no Proxmox alert had ever been delivered**. Sending through SES with a verified domain fixes deliverability:

| Mechanism | Setup |
|---|---|
| DKIM | SES Easy DKIM, 2048-bit, 3 CNAME records in Route 53 |
| SPF | Custom MAIL FROM subdomain (`bounce.example.com`) with its own MX + SPF; the domain's main SPF (Microsoft 365) is untouched |
| DMARC | `p=none` with aggregate reports to the shared mailbox, to be tightened to `quarantine` once reports are clean |

Test messages arrived in the inbox (not junk) with SPF, DKIM and DMARC all passing.

## Least Privilege

- The SMTP IAM user has one permission: `ses:SendRawEmail`, only from the alert address (`ses:FromAddress` condition)
- SES stays in the **sandbox**: 200 messages/day, 1/second, and only to verified addresses on the domain. A leaked credential can only email the domain's own mailbox, at a worst-case cost of cents per month
- SMTP credentials were written straight into each system's config from a root-only file; they never appear in documentation or chat logs

## What Alerts

| Source | Sends | Configuration |
|---|---|---|
| TrueNAS | Alerts at **Warning** and above: pool degraded, disk faulted, SMART errors, scrub problems, temperature | System → Alert Settings → E-Mail |
| Proxmox | **Warning / Error** notifications (failed backup jobs, etc.) and forwarded root mail (cron output, severity `unknown`) | SMTP target `ses-homelab` + matcher; the built-in Gmail matcher is disabled |
| Diun | New container image versions, weekly | [docker/diun](../docker/diun/README.md) |
| Laptop backup | Desktop notification on failure | [backups](../backups/README.md) |

Successful backups and "updates available" notices are informational and deliberately not emailed.

## Cloud Cost Guardrails

| Guardrail | Alert |
|---|---|
| AWS Budget `homelab-monthly`, $10/month | Email at $8 actual and when forecast > $10 |
| Automatic hard block at $15 actual | AWS Budgets attaches a deny policy to the off-site uploader users ([details](../backups/offsite/README.md#cost-controls)) |
| Cost Anomaly Detection | Daily summary of anomalies ≥ $2 |
| Zero-spend budget | Email at the first $0.01 (pre-existing) |

Expected spend is about $2–3/month: Route 53 (~$0.50) plus ~1.1 TB of off-site backups in Glacier Deep Archive. The budget alerts early; the hard block caps the one realistic runaway (a leaked uploader key), and uploads are already restricted to the cheapest storage class.

## Planned

- Metrics and dashboards (Proxmox, TrueNAS, containers) — see the main README
