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
|Current Allocation|2.03T|
|Free Space|23.3T|
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
    +-- sdb (12.7T) - ST14000NM005G-2KG133 [Serial: ZTM09FD7]
    +-- sdc (12.7T) - ST14000NM005G-2KG133 [Serial: ZLM2BF4E]
    +-- sdd (12.7T) - ST14000NM005G-2KG133 [Serial: ZTM093QT]
```

### Boot Pool
```
boot-pool (19G)
|
+-- sda3 (19.5G)
```

## Hardware Details

### Storage Disks

|Device|Model|Capacity|Serial Number|Purpose|
|---|---|---|---|---|
|sdb|ST14000NM005G-2KG133|14TB|ZTM09FD7|Datastore RAIDZ1|
|sdc|ST14000NM005G-2KG133|14TB|ZLM2BF4E|Datastore RAIDZ1|
|sdd|ST14000NM005G-2KG133|14TB|ZTM093QT|Datastore RAIDZ1|
|sda|QEMU HARDDISK|20G|drive-scsi0|Boot device (VM)|

**Note:** Model ST14000NM005G is Seagate Exos X14 - 14TB Enterprise HDD (7200 RPM, 256MB cache, 12Gb/s SAS)

## Dataset Hierarchy

Based on actual `zfs list -r datastore` output:

```
datastore/
|
+-- .system/                           # System datasets (legacy)
|   |
|   +-- configs-ae32c386e13840b2bf9c0083275e7941/
|   +-- cores/
|   +-- netdata-ae32c386e13840b2bf9c0083275e7941/
|   +-- nfs/
|   +-- samba4/
|
+-- Movies/                            # Movie media files
+-- Music/                             # Music media files
+-- NAS/                               # General NAS storage
|   |
|   +-- nas/                           # NAS subdirectory (2.03T used)
|
+-- TV_Shows/                          # TV show media files
```

### Dataset Details

|Dataset|Used|Available|Refer|Mountpoint|
|---|---|---|---|---|
|datastore|2.03T|23.3T|128K|/mnt/datastore|
|datastore/.system|1.84G|23.3T|1.47G|legacy|
|datastore/.system/configs-*|26.2M|23.3T|26.2M|legacy|
|datastore/.system/cores|128K|1024M|128K|legacy|
|datastore/.system/netdata-*|356M|23.3T|356M|legacy|
|datastore/.system/nfs|165K|23.3T|165K|legacy|
|datastore/.system/samba4|261K|23.3T|261K|legacy|
|datastore/Movies|128K|23.3T|128K|/mnt/datastore/Movies|
|datastore/Music|128K|23.3T|128K|/mnt/datastore/Music|
|datastore/NAS|2.03T|23.3T|128K|/mnt/datastore/NAS|
|datastore/NAS/nas|2.03T|24.0T|1.35T|-|
|datastore/TV_Shows|128K|23.3T|128K|/mnt/datastore/TV_Shows|

## Dataset Properties

**Current Configuration:**
- Most datasets use default 128K recordsize
- All datasets inherit lz4 compression from pool
- System datasets are marked as "legacy" mountpoints
- Primary data is stored in datastore/NAS/nas (2.03T)

**Recommended Optimizations:**

|Dataset|Recommended Record Size|Compression|Quota|Purpose|
|---|---|---|---|---|
|datastore/Movies|1M|lz4|None|Large sequential video files|
|datastore/TV_Shows|1M|lz4|None|Large sequential video files|
|datastore/Music|128K|lz4|None|Smaller audio files|
|datastore/NAS|128K|lz4|None|Mixed general purpose|

### Record Size Recommendations

- **128K (default)** - General purpose, mixed workloads
- **1M** - Large sequential files (movies, TV shows, ISOs)
- **16K** - Databases (if hosting any)

### Applying Optimizations

```bash
# Optimize for large video files
zfs set recordsize=1M datastore/Movies
zfs set recordsize=1M datastore/TV_Shows

# Keep default for general storage
# (datastore/Music and datastore/NAS already use 128K default)
```

## RAIDZ1 Configuration Notes

### Redundancy
- **Parity Disks:** 1
- **Fault Tolerance:** Can survive 1 disk failure
- **Usable Capacity:** (N-1) Ã— Disk Size = 2 Ã— 14TB â‰ˆ 25.4T usable

### Performance Characteristics
- **Read Performance:** Excellent (parallelized across all disks)
- **Write Performance:** Good (limited by parity calculation)
- **Rebuild Time:** ~12-24 hours for 14TB drives (depends on usage)
- **Risk Window:** Extended rebuilds increase URE (Unrecoverable Read Error) risk

### Capacity Planning
- Current usage: 2.03T used / 23.3T available (8% utilization)
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

**Status:** Configured via TrueNAS WebUI on January 28, 2026

All datasets are configured with weekly snapshots to provide protection against accidental deletion and data corruption. Snapshots are retained for 4 weeks, providing a month-long recovery window.

### Configured Snapshot Tasks

|Dataset|Recursive|Schedule|Retention|Naming Schema|Status|
|---|---|---|---|---|---|
|datastore/NAS|Yes|Weekly at 04:00|4 weeks|auto-%Y-%m-%d_%H-%M|Enabled|
|datastore/Movies|No|Weekly at 05:00|4 weeks|auto-%Y-%m-%d_%H-%M|Enabled|
|datastore/TV_Shows|No|Weekly at 06:00|4 weeks|auto-%Y-%m-%d_%H-%M|Enabled|
|datastore/Music|No|Weekly at 07:00|4 weeks|auto-%Y-%m-%d_%H-%M|Enabled|

### Schedule Details

- **Frequency:** Weekly (every Sunday)
- **Time Window:** 04:00-07:00 (4 AM - 7 AM)
- **Staggered Start:** 1 hour between each dataset to distribute I/O load
- **Retention:** 4 weeks (28 days) per dataset
- **Total Snapshots:** Maximum of 4 snapshots per dataset at any time

### Storage Impact

With current data patterns:
- **Estimated overhead:** <5% of used space (snapshots store only changes)
- **Current used space:** 2.03T
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
- Media datasets (Movies, TV_Shows, Music) use non-recursive snapshots (no subdirectories)
- System datasets (.system) managed automatically by TrueNAS
- Snapshots are local only - consider offsite backups for critical data

## Scrub Schedule

**Status:** Configured and automated

### Current Schedule

- **Pool:** datastore
- **Frequency:** Monthly
- **Next Run:** In 3 days (approximately February 1, 2026 at 00:00)
- **Purpose:** Verify data integrity and detect bit rot

### Scrub Configuration

- **Schedule:** Monthly at 00:00 (midnight)
- **Duration:** Typically 50-60 minutes for current 2.03T of data
- **Automatic:** Yes - runs automatically per schedule
- **Notification:** Configured through TrueNAS alert system

### Last Scrub Results

**Datastore Pool:**
- **Date:** January 25, 2026 at 00:56:04
- **Duration:** 56 minutes 3 seconds
- **Data Repaired:** 0 bytes
- **Errors Found:** 0
- **Status:** âœ“ Healthy

**Boot Pool:**
- **Date:** January 28, 2026 at 03:45:03
- **Duration:** 2 seconds
- **Data Repaired:** 0 bytes
- **Errors Found:** 0
- **Status:** âœ“ Healthy

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
- **Used:** 2.03T / 25.4T usable (8% utilization)
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
- Disk 1 (sdb): ZTM09FD7
- Disk 2 (sdc): ZLM2BF4E
- Disk 3 (sdd): ZTM093QT

**Import Command:**
```bash
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
# Increase recordsize for large files
zfs set recordsize=1M datastore/Movies
zfs set recordsize=1M datastore/TV_Shows
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