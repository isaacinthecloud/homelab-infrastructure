<h1>Home Network & Homelab Infrastructure</h1>

### Infrastructure Design, Virtualization, Storage, and Self-Hosted Services

<h2>Description</h2>
This project documents the design and implementation of my home network and homelab environment. The goal was to build a secure, scalable, and production-style setup that mirrors small-enterprise infrastructure patterns while remaining manageable in a home environment.
<br/>
<br />

The environment integrates enterprise-grade networking hardware, virtualization, software-defined storage, and containerized services. Emphasis was placed on network segmentation, service isolation, storage reliability, and self-hosting critical services such as DNS filtering and media automation.
<br/>

<h2>Core Technologies & Utilities Used</h2>

- <b>Ubiquiti Cloud Gateway Max</b>
- <b>Ubiquiti U7 Pro AP</b>
- <b>Proxmox VE</b> (Type-1 Hypervisor)
- <b>TrueNAS Scale</b> (Virtual Machine)
- <b>Docker</b> (Containerization)
- <b>AdGuard Home</b>
- <b>Tailscale</b> (Remote Access)
- <b>Traefik</b> (Reverse Proxy, Let's Encrypt DNS-01)
- <b>Home Media Management</b>
- <b>ZFS</b>
- <b>restic</b> (Encrypted Backups)
- <b>AWS</b> (Route 53, SES, Budgets)

<h2>Environments Used</h2>

- <b>On-Prem / Home Lab</b>
- <b>Linux-based Virtual Machines</b>
- <b>Containerized Services</b>

<h2>Network Architecture</h2>

<p>
The network is built around a Ubiquiti Cloud Gateway Max acting as the primary router, firewall, and VLAN controller. A WiFi 7 access point provides high-throughput wireless connectivity while maintaining centralized management through the Ubiquiti ecosystem.
</p>

<p>
Network segmentation is implemented using VLANs to isolate trusted devices, infrastructure services, and future expansion (e.g., guest or IoT networks). This approach improves security by reducing lateral movement and mirrors real-world enterprise network design.
</p>

<h2>Virtualization & Storage Design</h2>

<p>
Proxmox VE serves as the base operating system and hypervisor, allowing flexible management of virtual machines and containers. Storage is passed directly through to a TrueNAS virtual machine, enabling TrueNAS to manage disks using ZFS.
</p>

<p>
This design was chosen over running TrueNAS bare-metal to maintain flexibility at the hypervisor layer while still benefiting from ZFS features such as data integrity checks, snapshots, and expandability. Direct disk passthrough ensures TrueNAS maintains full control of storage devices.
</p>

<h2>Containerized Services</h2>

<p>
Core network services run in their own LXC containers (AdGuard Home for DNS filtering, Tailscale for remote access), so they stay up even if the Docker host is down. A dedicated Docker LXC hosts:
</p>

<ul>
  <li><b>Traefik</b> - HTTPS reverse proxy with Let's Encrypt certificates via DNS-01</li>
  <li><b>ARR Suite + qBittorrent</b> - Automated media management, routed through a Gluetun VPN container</li>
  <li><b>Jellyfin</b> - Media server with Intel Quick Sync hardware transcoding</li>
  <li><b>Syncthing</b> - Always-on sync hub for an Obsidian vault</li>
  <li><b>Seerr + Trailarr</b> - Media requests for household users, and local trailers for the library</li>
  <li><b>Immich</b> - Self-hosted photo library with OpenVINO machine learning on the iGPU</li>
  <li><b>Diun</b> - Weekly email when a pinned container image has a newer version</li>
</ul>

<p>
<b>Home Assistant OS</b> runs in its own VM, dual-homed on the trusted and IoT VLANs, with the Proxmox firewall dropping unsolicited traffic from IoT devices (see <a href="homeassistant/README.md">homeassistant</a>).
</p>

<p>
Running these services in containers provides isolation, simplified updates, and portability. This approach avoids tight coupling between services and the host OS while allowing quick recovery or migration if needed.
</p>

<h2>Key Outcomes & Skills Demonstrated</h2>

<ul>
  <li>Designed and implemented a segmented network using enterprise-grade hardware</li>
  <li>Deployed and managed a Type-1 hypervisor with virtualized storage</li>
  <li>Configured ZFS-backed NAS services with disk passthrough</li>
  <li>Deployed containerized services with an emphasis on isolation and maintainability</li>
  <li>Applied real-world infrastructure and DevOps principles in a home lab environment</li>
  <li>Designed layered backups (Proxmox guests, host config, ZFS snapshots, encrypted laptop backups) with failure alerting, plus encrypted off-site copies in AWS Glacier Deep Archive behind least-privilege IAM, versioning and an automatic cost hard-block</li>
  <li>Built authenticated email alerting (SPF, DKIM, DMARC via AWS SES) with least-privilege IAM and cloud cost guardrails</li>
  <li>Ran a full patch cycle (TrueNAS train upgrades, Proxmox, LXC, Docker 28 → 29) and documented a repeatable runbook</li>
</ul>

<h2>Repository Layout</h2>

| Folder | Contents |
|---|---|
| [ubiquiti](ubiquiti/README.md) | VLAN design and gateway configuration |
| [proxmox](proxmox/README.md) | Hypervisor, bridges, LXC and VM configuration |
| [truenas](truenas/README.md) | ZFS pool, datasets, shares, disk passthrough |
| [docker](docker/README.md) | Compose stack, Traefik, media stack, Syncthing, Diun |
| [adguard](adguard/README.md) / [tailscale](tailscale/README.md) | DNS filtering and remote access |
| [homeassistant](homeassistant/README.md) | Home Assistant VM, IoT VLAN access, Proxmox firewall |
| [backups](backups/README.md) | Backup layers, schedules, laptop restic scripts |
| [monitoring](monitoring/README.md) | Email alerting and cost guardrails |
| [security](security/README.md) | Threat model, hardening, secrets handling |
| [docs/maintenance.md](docs/maintenance.md) | Update runbook and lessons learned |
| [diagrams](diagrams/README.md) | Architecture diagrams |

<h2>Planned Improvements & Future Enhancements</h2>

<p>
While the current environment is fully functional, the homelab is designed to evolve over time. Planned improvements focus on security, usability, and aligning more closely with production-grade infrastructure patterns.
</p>

<ul>
  <li>
    <b>Centralized Authentication & Authorization</b><br/>
    Future plans include integrating an authentication provider (e.g., Authelia or Authentik) with Traefik middleware to provide single sign-on (SSO), stronger access control, and consistent authentication across all internal services.
  </li>

  <li>
    <b>Monitoring & Metrics</b><br/>
    Email alerting is in place (see <a href="monitoring/README.md">monitoring</a>). Next: centralized metrics and dashboards for Proxmox, Docker containers, and TrueNAS to show resource utilization, service health, and long-term trends.
  </li>
  <li>
    <b>Restore Testing</b><br/>
    Layered on-site backups and encrypted off-site copies in AWS S3 Glacier Deep Archive are in place (see <a href="backups/README.md">backups</a>). Next: scheduled restore tests.
  </li>
</ul>
