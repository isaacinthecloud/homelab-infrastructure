# Diagrams

Architecture diagrams for the homelab, from network topology down to individual services. They are written in [Mermaid](https://mermaid.js.org/), so GitHub and Obsidian render them directly from this file and they can be updated in the same commit as the change they describe.

---

## Network Topology (Logical View)

```mermaid
flowchart TB
    internet(("Internet"))
    modem["ISP modem<br/>(first NAT)"]
    gw["Ubiquiti Cloud Gateway Max<br/>routing · NAT · firewall · DHCP · VLANs"]
    ap["Ubiquiti U7 Pro AP<br/>SSIDs mapped to VLAN 21 / 210 / 1610"]
    sw["Wired clients"]
    aws["AWS<br/>Route 53 (DNS-01) · SES (alerts) · S3 (off-site backups)"]

    internet --- modem --- gw
    gw --- ap
    gw --- sw
    internet -.- aws

    subgraph vlans["VLAN segmentation"]
        direction LR
        v1["VLAN 1 · Management<br/>10.2.0.0/24"]
        v21["VLAN 21 · Trusted<br/>10.2.1.0/24"]
        v210["VLAN 210 · IoT<br/>10.2.10.0/24<br/>no east-west"]
        v1610["VLAN 1610 · Guest<br/>192.168.10.0/24<br/>internet only"]
    end
    gw == "802.1Q trunk" ==> vlans

    subgraph pve["Proxmox VE host (VLAN 21) · enp4s0 → vmbr0 (VLAN-aware)"]
        direction LR
        adg["LXC 101<br/>AdGuard Home<br/>DNS for all VLANs"]
        ts["LXC 102<br/>Tailscale<br/>subnet router 10.2.1.0/24"]
        dock["LXC 103<br/>Docker host<br/>Traefik · media · Syncthing"]
        nas["VM 100<br/>TrueNAS SCALE<br/>ZFS RAIDZ1"]
    end
    v21 --> pve

    remote["Remote clients<br/>(laptop, phone)"] -. "WireGuard" .-> ts
    ts -. "HTTPS" .-> dock
    dock -- "NFS via host bind mounts" --> nas
    adg -. "DNS" .- v210
    adg -. "DNS" .- v1610
```

**Security highlights**
- No inbound port forwarding; remote access only through Tailscale
- Firewall rules between VLANs; IoT has no east-west traffic, guests are internet-only
- TLS for every internal service via Let's Encrypt DNS-01 (no ports 80/443 opened)
- Download traffic leaves only through a VPN tunnel (Gluetun)
- Double NAT (ISP modem → gateway)

---

## Proxmox Networking & Guests

```mermaid
flowchart TB
    nic["enp4s0<br/>physical NIC · 802.1Q trunk"]
    nic --> vmbr0
    nic --> mgmt["vmbr0v21 (enp4s0.21)<br/>Proxmox host management<br/>10.2.1.x"]

    subgraph vmbr0["vmbr0 · Linux bridge, VLAN-aware (1, 21, 210, 1610)"]
        direction LR
        v101["veth101i0"]
        v102["veth102i0"]
        v103["veth103i0"]
        f100["fwpr100p0"]
        f104["fwpr104p0"]
    end

    v101 --> c101["LXC 101 · AdGuard<br/>1 vCPU · 512 MB · unprivileged<br/>boot order 1"]
    v102 --> c102["LXC 102 · Tailscale<br/>2 vCPU · 512 MB · unprivileged · /dev/net/tun<br/>boot order 2"]
    v103 --> c103["LXC 103 · Docker<br/>2 vCPU · 4 GB · privileged<br/>/data · /obsidian bind mounts · iGPU<br/>boot order 4"]
    f100 --> t100["tap100i0 → fwbr100i0"] --> vm100["VM 100 · TrueNAS<br/>4 vCPU · 16 GB<br/>SATA controller passthrough<br/>boot order 3 + 120 s"]
    f104 --> vm104["VM 104 · DC01<br/>AD lab (manual start)"]

    subgraph storage["Host storage"]
        nvme["NVMe · LVM-thin<br/>guest disks · local backups"]
        nfs["NFS storages from TrueNAS<br/>truenas-data · truenas-obsidian · truenas-backups"]
    end
    nfs -. "bind mounts" .-> c103
```

| Interface | Meaning |
|---|---|
| `vethXXXi0` | LXC container veth pair |
| `tapXXXi0` | KVM VM tap device |
| `fwbrXXXi0` / `fwprXXXp0` | Proxmox firewall bridge / its port on vmbr0 |

---

## TrueNAS ZFS Storage

```mermaid
flowchart TB
    subgraph phys["Physical layer · onboard SATA controller passed through (vfio-pci at boot)"]
        direction LR
        d1[("Exos X14<br/>14 TB")]
        d2[("Exos X14<br/>14 TB")]
        d3[("Exos X14<br/>14 TB")]
    end
    phys --> vdev["raidz1-0<br/>single parity · survives 1 disk failure"]
    vdev --> pool["Pool: datastore<br/>~25 TiB usable · lz4 · no dedup<br/>scrub every 35 days"]

    pool --> data["data/ · 1M<br/>torrents/ + media/<br/>(one filesystem → hardlinks)"]
    pool --> isaac["isaac/ · personal files<br/>+ Obsidian/ vault"]
    pool --> mio["mio/ · household member"]
    pool --> zvol["NAS/nas · 2 TB zvol"]
    pool --> bk["backups/<br/>proxmox/ · laptop/"]

    data -- "NFS (Proxmox host only)" --> pveh["Proxmox host"]
    isaac -- "NFS: Obsidian/" --> pveh
    bk -- "NFS: proxmox/" --> pveh
    pveh -- "bind mounts" --> lxc["LXC 103<br/>/data · /obsidian"]
    isaac -- "SMB" --> clients["Laptop / desktop"]
    mio -- "SMB" --> clients
    zvol -- "iSCSI" --> winpc["Windows PC"]
    bk -- "SFTP (restricted user)" --> laptop["Laptop restic"]
    pool -. "encrypted Cloud Sync" .-> s3[("AWS S3<br/>Deep Archive")]
```

**Snapshot tasks:** `isaac` daily, `backups/laptop` daily, `NAS` weekly (recursive), all kept 4 weeks. Media (`data`) is not snapshotted.

---

## Docker Container Architecture (LXC 103)

```mermaid
flowchart TB
    client["Client on LAN or Tailscale"] -- "HTTPS :443<br/>*.lab.example.com" --> traefik

    subgraph tnet["traefik-net (bridge)"]
        traefik["Traefik v3<br/>Let's Encrypt DNS-01 (Route 53)<br/>:80 → :443 redirect"]
        portainer["Portainer :9000"]
        jellyfin["Jellyfin :8096<br/>Intel Quick Sync<br/>/data/media (read-only)"]
        syncthing["Syncthing :8384<br/>sync :22000 tcp/quic<br/>/obsidian"]
        subgraph vpn["Gluetun · NordVPN tunnel · kill switch"]
            gluetun["Gluetun<br/>health-checked"]
            radarr["Radarr :7878"]
            sonarr["Sonarr :8989"]
            lidarr["Lidarr :8686"]
            prowlarr["Prowlarr :9696"]
            bazarr["Bazarr :6767"]
            flare["FlareSolverr :8191"]
            qbt["qBittorrent :8080"]
        end
    end
    diun["Diun<br/>weekly image check<br/>(no docker.sock)"]

    traefik --> portainer
    traefik --> jellyfin
    traefik --> syncthing
    traefik -- "labels on gluetun" --> gluetun
    prowlarr --> radarr & sonarr & lidarr
    prowlarr -. "Cloudflare challenges" .-> flare
    radarr & sonarr & lidarr --> qbt
    gluetun -. "only egress path" .-> vpnout(("VPN exit"))
    diun -. "email via SES" .-> mail(("Alert mailbox"))

    data[("/data<br/>torrents/ · media/")]
    qbt --> data
    radarr & sonarr & lidarr -- "hardlink import" --> data
    data --> jellyfin
```

**Key points**
- Only download and indexer traffic goes through the VPN; Jellyfin stays local for fast household streaming
- VPN apps share Gluetun's network namespace and start only after Gluetun is healthy
- All images pinned to exact versions; Diun reports new ones weekly
- Secrets come from `.env`; nothing sensitive is in the compose file

---

## Backup & Off-site Flow

See the diagram in [backups/offsite/README.md](../backups/offsite/README.md): Proxmox and TrueNAS upload encrypted copies to AWS S3 Glacier Deep Archive, with the TrueNAS VM backup going directly from Proxmox so it never depends on TrueNAS.

---

## Obfuscation Policy

These diagrams intentionally omit or anonymize:
- Public IP addresses
- Individual host IP addresses (shown as `10.2.1.x`)
- VPN or overlay network node identifiers
- Cloud account identifiers

CIDR ranges and VLAN IDs are included, as they are not considered sensitive for documentation purposes.
