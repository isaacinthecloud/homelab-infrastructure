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

Major version upgrades (e.g. Proxmox VE 8 → 9) are planned separately.

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
