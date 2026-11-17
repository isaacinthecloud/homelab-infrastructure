# Maintenance & Update Runbook

Updates are done in one planned session, in dependency order, with a way back at each step. Order used: **TrueNAS → Proxmox host → LXC containers → Docker images**.

## 1. TrueNAS SCALE

1. Export the config **including the secret seed** (System → General → Manage Configuration → Download) and keep it offline
2. Check pool health and that no jobs (scrub, replication) are running
3. Apply the latest patch on the current train first, reboot, verify
4. Switch to the next train (e.g. `TrueNAS-SCALE-Fangtooth`) and upgrade; **one train at a time**
5. After each reboot: pool ONLINE, services running, NFS storages active on Proxmox, containers still see `/data`
6. **Don't** upgrade ZFS pool feature flags right away — it's one-way and prevents booting the older version. Wait until the new release has proven itself

Rollback: the previous version stays available as a boot environment.

API notes (`midclt`):
- `midclt call -j` takes an argument — start long jobs without it and poll `core.get_jobs` by ID
- Clients reconnect on their own; NFS hard mounts simply pause during the reboot

## 2. Proxmox Host

```bash
apt-get update
apt-get dist-upgrade          # never plain "upgrade" on Proxmox
reboot                        # new kernel
```

Guests come back in startup order (AdGuard → Tailscale → TrueNAS + 120 s → Docker). After the reboot, check that `pvesm status` shows every NFS storage active and that all containers are running.

Major version upgrades are planned separately (see below).

### Major upgrade: Proxmox VE 8 → 9 (done November 2026)

Proxmox VE 8 reached end of life in August 2026: apt stops offering updates, so "nothing to upgrade" doesn't mean the host is current. Upgraded 8.4.21 → **9.2.28** (Debian 12 → 13, kernel 6.8 → 7.0) in one evening with about 10 minutes of downtime.

1. **Back up first.** Fresh `vzdump` of the core guests marked `--protected 1` (so retention can't prune them), the host `/etc` archive, and `dpkg --get-selections`. Keep one copy off the Proxmox host
2. **Run `pve8to9 --full`** until it reports 0 failures. Here the only failure was the unused `systemd-boot` meta-package (the host boots with GRUB); removing it was safe
3. **Pin the NIC name** (see [Network Bridges](../proxmox/network-bridges.md)) so a renamed interface can't take the host off the network
4. **Switch the repos to trixie**, using deb822 `.sources` files: Debian (add `non-free-firmware`), `pve-no-subscription`, and `ceph-squid` (Ceph client libraries are installed even without Ceph). Nothing installs packages automatically on the host, so this can be done hours ahead
5. **Download first:** `apt-get dist-upgrade --download-only` while everything is still running, to keep the outage short
6. **Stop the LXC containers.** The TrueNAS VM can stay up until the reboot: a running VM keeps using its old QEMU binary, and keeping it up stops the host's NFS mounts from hanging during the upgrade
7. **Upgrade** with `dist-upgrade` in a session that survives an SSH drop (`tmux`, or a `systemd-run` unit with a log file). Keep your own config files when asked. Here that meant `lvm.conf` (it has Proxmox's `global_filter`) and `/etc/issue`
8. **Before rebooting**, check that the new kernel's initramfs contains the vfio and NIC-pinning files, that GRUB's default entry is the new kernel, and that `sshd -t` passes
9. **After rebooting**, check that 00:17 is bound to `vfio-pci`, the host sees no SATA disks or pools, there are no failed units, guests start in order, NFS storages are active, all containers are up, the VPN exits where expected, Jellyfin QSV works, and Traefik routes respond
10. **Install `intel-microcode`** (`dist-upgrade` doesn't add new packages) and reboot once more

Rollback: there is no in-place downgrade. Reinstall Proxmox VE 8, restore `/etc` and the protected guest backups. Unprotect those backups after a few days of stable running.

### Major upgrade: LXC containers Debian 12 → 13 (done November 2026)

Done right after the host upgrade, one container at a time (AdGuard → Tailscale → Docker), checking each before moving on. Each service was down only for its container's reboot. Docker took a minute or two longer because dockerd restarts during the upgrade.

1. **Back up:** `vzdump <ids> --protected 1` to the NAS
2. **Check sysctl settings first.** Debian 13 removes the `/etc/sysctl.d/99-sysctl.conf` → `/etc/sysctl.conf` symlink, so anything in `/etc/sysctl.conf` silently stops applying at the next boot. The Tailscale container's `ip_forward` lived there, and without it the subnet route would break with no error. Move such settings to their own file in `/etc/sysctl.d/` before upgrading
3. **Switch the repos:** `sed -i s/bookworm/trixie/g` in `sources.list` and the third-party `.list` files (Tailscale and Docker both publish trixie repos)
4. **Upgrade** with `dist-upgrade`, keeping your own config files, then `pct reboot <id>`
5. **Verify:**
   - AdGuard resolves
   - Tailscale has `ip_forward = 1` and still advertises the subnet
   - Docker: all containers up, VPN egress correct, NFS bind mounts present, QSV works, Traefik routes respond

AdGuard Home is a standalone binary in `/opt`, so apt doesn't touch it. Optional follow-ups: `apt modernize-sources` (converts to deb822 `.sources` files) and `apt autoremove`.

## 3. LXC Containers

```bash
pct exec <id> -- sh -c 'apt-get update && apt-get dist-upgrade -y'
```

Upgrading Docker inside LXC 103 restarts dockerd. Run `docker compose up -d` afterwards to cover the Gluetun start-order race.

## 4. Docker Images

Images are pinned. Diun emails when a new version exists. To update:

```bash
cd /root/docker
cp docker-compose.yml docker-compose.yml.bak-$(date +%F)
# edit the image tag(s), after reading release notes
docker compose pull <service>
docker compose up -d <service>
```

- Keep old images until the new version has run for a while. Don't `docker image prune` right after an update, or you lose the local rollback
- Apps with databases (*arr, Jellyfin) migrate their schema on upgrade; a true rollback may also need the config folder restored from the nightly backup

## Lessons Learned (November 2026 update session)

| Issue | Cause | Fix |
|---|---|---|
| 3 containers down after every reboot | dockerd starts VPN apps before Gluetun exists; `unless-stopped` doesn't retry "cannot join network namespace" | `compose-stack.service` runs `docker compose up -d` after boot |
| Host scanning TrueNAS's pools at boot | SATA controller owned by the host's `ahci` driver until the VM started | Bind the controller to `vfio-pci` at boot; mask the host's ZFS import units |
| Proxmox alerts never delivered | Direct mail from a home IP rejected by Gmail (no SPF/DKIM) | Send through AWS SES |
| Docker 28 → 29 | New minimum Docker API version breaks older Traefik/Portainer | Update those images in the same change |
| Pinning recreated every container | Compose treats a changed `image:` string as a config change | Expect a brief restart when changing tags |
| Diun watching ancient tags | Four-part version tags don't sort as semver | Watch `:latest` digests for those images |
| Proxmox VE 8 quietly end-of-life | EOL repos just stop offering updates; apt looks "up to date" | Track the Proxmox lifecycle table, not apt output |
| `pve8to9` failure: systemd-boot | Debian meta-package installed but never used (host boots with GRUB) | `apt remove systemd-boot` |
| Microcode still old after the upgrade | `dist-upgrade` only upgrades installed packages | Install `intel-microcode` from `non-free-firmware` |
| Debian 13 drops `/etc/sysctl.conf` | procps removes the `99-sysctl.conf` symlink | Keep sysctl settings in `/etc/sysctl.d/*.conf` |
