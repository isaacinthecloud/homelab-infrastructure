<h1>Home Network & Homelab Infrastructure</h1>

### Infrastructure Design, Virtualization, Storage, and Self-Hosted Services

<h2>Description</h2>
This project documents the design and implementation of my home network and homelab environment. The goal was to build a secure, scalable, and production-style setup that mirrors small-enterprise infrastructure patterns while remaining manageable in a home environment.

The environment integrates enterprise-grade networking hardware, virtualization, software-defined storage, and containerized services. Emphasis was placed on network segmentation, service isolation, storage reliability, and self-hosting critical services such as DNS filtering and media automation.
<br />

<h2>Core Technologies & Utilities Used</h2>

- <b>Ubiquiti Cloud Gateway Max</b>
- <b>Ubiquiti U7 Pro AP</b>
- <b>Proxmox VE</b> (Type-1 Hypervisor)
- <b>TrueNAS Scale</b> (Virtual Machine)
- <b>Docker</b> (Containerization)
- <b>AdGuard Home</b>
- <b>Home Media Management</b>
- <b>ZFS</b>

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
Docker is used to host lightweight services, including:
</p>

<ul>
  <li><b>AdGuard Home</b> - Network-wide DNS-based ad and tracker blocking</li>
  <li><b>ARR Suite</b> - Automated media management and orchestration</li>
</ul>

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
</ul>

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
    <b>Monitoring, Metrics, and Alerting</b><br/>
    Implementing centralized monitoring to collect metrics from Proxmox, Docker containers, and TrueNAS. This will improve visibility into resource utilization, service health, and long-term trends.
  </li>
  <li>
    <b>Backup & Disaster Recovery Strategy</b><br/>
    Implementing a structured backup strategy for critical data and configurations including off-host backups of application configs and documented recovery procedures to protect against data loss, misconfiguration, or hardware failure.
  </li>
</ul>
