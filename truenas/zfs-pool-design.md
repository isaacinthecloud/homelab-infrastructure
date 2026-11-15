# ZFS Pool Design

## Overview

This document details the ZFS pool configuration for the TrueNAS homelab storage system. The primary storage pool uses RAIDZ1 for redundancy with three 14TB enterprise drives.

## Pool Configuration

### Main Storage Pool (datastore)

|Setting|Value|
|---|---|
|Pool Name|datastore|
|VDEV Layout|RAIDZ1 (single parity)|
|Number of Disks|3|
|Disk Size|14TB (12.7T usable per disk)|
|Total Raw Capacity|38.2T|
|Usable Capacity|~25.4T (after RAIDZ1 overhead)|
|Current Allocation|~3.1T (Nov 2026)|
|Free Space|~22.2T|
|Compression|lz4|
|Deduplication|Off|
|Atime|Off|
|Record Size|128K (default)|

### Boot Pool (boot-pool)

|Setting|Value|
|---|---|
|Pool Name|boot-pool|
|VDEV Layout|Single disk (no redundancy)|
|Disk|sda3|
|Size|19.5G (19G usable)|
|Purpose|TrueNAS OS installation|

## VDEV Layout

### Datastore Pool
```
datastore (38.2T)
|
+-- raidz1-0
    |
    +-- sdb (12.7T) - ST14000NM005G-2KG133
    +-- sdc (12.7T) - ST14000NM005G-2KG133
    +-- sdd (12.7T) - ST14000NM005G-2KG133
```

### Boot Pool
```
boot-pool (19G)
|
+-- sda3 (19.5G)
```

## Hardware Details

### Storage Disks

|Device|Model|Capacity|Purpose|
|---|---|---|---|
|sdb|ST14000NM005G-2KG133|14TB|Datastore RAIDZ1|
|sdc|ST14000NM005G-2KG133|14TB|Datastore RAIDZ1|
|sdd|ST14000NM005G-2KG133|14TB|Datastore RAIDZ1|
|sda|QEMU HARDDISK|20G|Boot device (VM)|

Serial numbers are intentionally omitted from this public repository.

**Note:** Model ST14000NM005G is Seagate Exos X14 - 14TB Enterprise HDD (7200 RPM, 256MB cache, 12Gb/s SAS)

## Dataset Hierarchy

Current layout (`zfs list -r datastore`, system datasets omitted). The original `Movies`, `TV_Shows` and `Music` datasets were removed in November 2026 (they were empty) and replaced by a single `data` dataset so the media apps can hardlink instead of copy.

```
datastore/
|
+-- data/            # media/ + torrents/ on ONE filesystem (hardlinks)   NFS -> Proxmox host
+-- isaac/           # personal files                                    SMB
|   +-- Obsidian/    #   (folder) Obsidian vault for Syncthing           NFS -> Proxmox host
+-- mio/             # second household member                           SMB
+-- NAS/
|   +-- nas          # 2TB zvol                                          iSCSI
+-- backups/
    +-- proxmox/     # vzdump guest backups + host config archives       NFS -> Proxmox host
    +-- laptop/      # restic repository (encrypted)                     SFTP
```

## Dataset Properties

|Dataset|Record Size|Compression|Why|
|---|---|---|---|
|datastore/data|1M|lz4|Large sequential media files and downloads|
|datastore/isaac|128K|lz4|Mixed personal files|
|datastore/mio|128K|lz4|Mixed personal files|
|datastore/NAS|128K|lz4|Container for the iSCSI zvol|
|datastore/backups|1M|lz4|Large backup archives and restic pack files|

### Record Size Recommendations

- **128K (default)** - General purpose, mixed workloads
- **1M** - Large sequential files (media, backups, ISOs)
- **16K** - Databases (if hosting any)

### Why One `data` Dataset?

A hardlink can't cross a filesystem boundary, and every ZFS dataset is its own filesystem. With downloads and libraries in separate datasets, every import is a full copy (twice the space, minutes of I/O). With both under `datastore/data`, an import is an instant hardlink and the torrent keeps seeding from the same blocks.

## RAIDZ1 Configuration Notes

### Redundancy
- **Parity Disks:** 1
- **Fault Tolerance:** Can survive 1 disk failure
- **Usable Capacity:** (N-1) × Disk Size = 2 × 14TB ≈ 25.4T usable

### Performance Characteristics
- **Read Performance:** Excellent (parallelized across all disks)
- **Write Performance:** Good (limited by parity calculation)
- **Rebuild Time:** ~12-24 hours for 14TB drives (depends on usage)
- **Risk Window:** Extended rebuilds increase URE (Unrecoverable Read Error) risk

### Capacity Planning
- Current usage (Nov 2026): ~3.1T used / ~22.2T available (~12% utilization)
- **Warning threshold:** 80% (recommend expansion/cleanup)
- **Critical threshold:** 90% (performance degradation)

## Pool Health Status

**Last Status Check:** January 28, 2026

### Datastore Pool
- **State:** ONLINE
- **Scan:** Last scrub repaired 0B in 00:56:03 with 0 errors (Jan 25, 2026)
- **Read Errors:** 0
- **Write Errors:** 0
- **Checksum Errors:** 0

### Boot Pool
- **State:** ONLINE
- **Scan:** Last scrub repaired 0B in 00:00:02 with 0 errors (Jan 28, 2026)
- **Read Errors:** 0
- **Write Errors:** 0
- **Checksum Errors:** 0

## Snapshot Policy

**Status:** Reviewed November 2026

Snapshots protect against accidental deletion, ransomware-style overwrites from a client, and bad sync events. Retention is 4 weeks everywhere.

### Configured Snapshot Tasks

|Dataset|Recursive|Schedule|Retention|Naming Schema|Why|
|---|---|---|---|---|---|
|datastore/NAS|Yes|Weekly, Sunday 04:00|4 weeks|auto-%Y-%m-%d_%H-%M|iSCSI zvol for the Windows PC|
|datastore/isaac|No|Daily 00:00|4 weeks|auto-%Y-%m-%d_%H-%M|Personal files + Obsidian vault|
|datastore/backups/laptop|No|Daily 04:30|4 weeks|auto-%Y-%m-%d_%H-%M|Protects the restic repo even if the laptop is compromised|

`datastore/data` is not snapshotted: media can be re-acquired, and snapshots would pin deleted media on disk.

### Storage Impact

With current data patterns:
- **Estimated overhead:** <5% of used space (snapshots store only changes)
- **Current used space:** ~3.1T (Nov 2026)
- **Maximum snapshot overhead:** ~100GB (conservatively estimated)
- **Impact on 23.3T available:** Negligible (<0.5%)

### Accessing Snapshots

Snapshots are accessible via the hidden `.zfs/snapshot` directory:

```bash
# List available snapshots for NAS dataset
ls /mnt/datastore/NAS/.zfs/snapshot/

# Browse snapshot contents
ls /mnt/datastore/NAS/.zfs/snapshot/auto-2026-02-02_04-00/

# Restore a single file from snapshot
cp /mnt/datastore/NAS/.zfs/snapshot/auto-2026-02-02_04-00/nas/file.txt /mnt/datastore/NAS/nas/file.txt
```

### Rollback Procedure (Emergency Only)

**WARNING:** Rollback is destructive - all changes since snapshot will be lost!

```bash
# List snapshots for a dataset
zfs list -t snapshot datastore/NAS

# Rollback to a specific snapshot (USE WITH CAUTION)
zfs rollback datastore/NAS@auto-2026-02-02_04-00

# Better: Clone snapshot for recovery testing
zfs clone datastore/NAS@auto-2026-02-02_04-00 datastore/NAS-recovery
```

### Monitoring Snapshots

```bash
# View all snapshots
zfs list -t snapshot -r datastore

# Check snapshot space usage
zfs list -o name,used,refer -t snapshot

# Verify snapshot tasks are running
midclt call pool.snapshottask.query | jq '.[] | {dataset, enabled, state}'
```

### Notes

- Recursive snapshots on datastore/NAS include the `/nas` subdirectory
- `datastore/isaac` and `datastore/backups/laptop` use non-recursive daily snapshots
- System datasets (.system) managed automatically by TrueNAS
- Snapshots are local only - an off-site copy (e.g. TrueNAS Cloud Sync) is still a planned improvement

## Scrub Schedule

**Status:** Configured and automated

### Current Schedule

- **Pool:** datastore
- **Frequency:** Every 35 days (TrueNAS default threshold, checked nightly at 00:00)
- **Purpose:** Verify data integrity and detect bit rot

### Scrub Configuration

- **Schedule:** Monthly at 00:00 (midnight)
- **Duration:** About an hour per 2T of data
- **Automatic:** Yes - runs automatically per schedule
- **Notification:** Configured through TrueNAS alert system

### Last Scrub Results

**Datastore Pool:**
- **Date:** November 8, 2026
- **Data Repaired:** 0 bytes
- **Errors Found:** 0
- **Status:** ✓ Healthy

**Boot Pool:**
- **Date:** January 28, 2026 at 03:45:03
- **Duration:** 2 seconds
- **Data Repaired:** 0 bytes
- **Errors Found:** 0
- **Status:** ✓ Healthy

### Scrub Impact

- **I/O Impact:** Low priority background operation
- **Performance Impact:** Minimal during scrub operation
- **Best Practice:** Scheduled during low-usage periods (midnight)
- **Recommended:** Run at least monthly for data integrity

### Monitoring Scrub Status

```bash
# View last scrub results
zpool status datastore | grep -A 1 "scan:"

# Check scrub history
zpool history datastore | grep scrub

# View scrub schedule
midclt call pool.scrub.query | jq
```

### Resilver Priority

**Configuration:** Resilvers (disk rebuilds) are prioritized during off-peak hours:
- **Active Window:** 18:00 - 09:00 (6 PM to 9 AM)
- **Days:** All days of the week
- **Purpose:** Faster rebuilds during low-usage periods
- **Status:** Enabled

This ensures that if a disk failure occurs, the resilver process will run at higher priority during evening/night hours when system usage is typically lower.

## Monitoring

### Key Metrics to Monitor

**Pool Health:**
```bash
zpool status datastore
zpool list datastore
```

**Disk SMART Data:**
```bash
smartctl -H /dev/sdb  # Check health status
smartctl -A /dev/sdb  # View all attributes
smartctl -A /dev/sdc
smartctl -A /dev/sdd
```

**Capacity Utilization:**
```bash
zfs list -o name,used,avail,refer,mountpoint datastore
```

**Scrub Status:**
```bash
zpool status -v datastore | grep -A 1 "scan:"
```

**ARC Statistics:**
```bash
arc_summary.py  # If available
# Look for: ARC size, hit rate, miss rate
```

### Alert Thresholds

|Metric|Warning|Critical|Action|
|---|---|---|---|
|Pool Capacity|80%|90%|Expand or clean up|
|Disk SMART Status|Any pre-fail|Failed attributes|Replace disk|
|Scrub Errors|1-10|>10|Investigate immediately|
|Read/Write Errors|>0|>5|Check cables/controller|

## Expansion Planning

### Current Situation
- **Used:** ~3.1T / 25.4T usable (~12% utilization, Nov 2026)
- **Available:** 23.3T
### Expansion Options

**Option 1: Add RAIDZ1 VDEV** (Recommended)
- Add another set of 3x 14TB drives
- Creates second raidz1-1 VDEV
- Doubles usable capacity to ~50T
- Maintains same fault tolerance per VDEV

**Option 2: Replace with Larger Disks**
- Replace each 14TB drive with 18TB or 20TB
- Requires replacing all 3 disks sequentially
- Risk: Extended resilver times during replacement
- Not recommended for RAIDZ1 (rebuild stress)

**Option 3: Migrate to RAIDZ2** (Future)
- Better fault tolerance (2 disk failures)
- Requires 4+ disks minimum
- Consider when expanding storage significantly

### Expansion Procedure (Adding VDEV)
```bash
# 1. Verify new disks
lsblk -d -o NAME,SIZE,MODEL,SERIAL

# 2. Add new VDEV to existing pool
zpool add datastore raidz1 sdX sdY sdZ

# 3. Verify configuration
zpool status -v datastore
```

## Disaster Recovery

### Critical Information for Recovery

**Pool Configuration:**
- Pool name: `datastore`
- VDEV type: `raidz1`
- Disk count: 3
- Disk model: Seagate Exos X14 14TB (ST14000NM005G-2KG133)

**Disk Serials (CRITICAL - for RMA/replacement):**
- Recorded privately (TrueNAS → Storage → Disks); omitted from this public repository

**Import Command:**
```bash
# Run INSIDE TrueNAS only. Never import this pool on the Proxmox host:
# both systems would write to it and the pool would be corrupted.
# If pool becomes unavailable, try:
zpool import -f datastore

# If pool needs to be found:
zpool import
```

### Single Disk Failure Procedure
1. Identify failed disk: `zpool status datastore`
2. Order replacement (same size or larger)
3. Physically replace disk
4. Resilver: `zpool replace datastore <old-disk> <new-disk>`
5. Monitor: `zpool status -v datastore` (watch resilver progress)

### Multiple Disk Failure
- **CRITICAL:** RAIDZ1 can only survive 1 disk failure
- If 2+ disks fail simultaneously: DATA LOSS
- Recovery requires restoring from backups

## Performance Tuning

### Current Settings
- Record size: 128K (default for most datasets)
- Compression: lz4 (inherited from pool)
- Atime: Off (reduces write I/O)
- Deduplication: Off (saves RAM)

### Recommendations

**For Sequential I/O (media serving):**
```bash
# Large sequential files (already applied to these datasets)
zfs set recordsize=1M datastore/data
zfs set recordsize=1M datastore/backups
```

**For Random I/O (databases, if any):**
```bash
# Decrease recordsize for small random I/O
zfs set recordsize=16K datastore/databases
```

**Verify current settings:**
```bash
zfs get recordsize,compression,atime datastore
```