#!/bin/bash
# zvol-offsite.sh - encrypted off-site copy of the iSCSI zvol (datastore/NAS/nas) to S3.
#
#   * Every ~180 days: new held "base" snapshot, full `zfs send` stream uploaded.
#   * Otherwise once a month: differential stream (base -> today) uploaded.
#   Only the base snapshot is kept on the NAS, so there is never a long incremental chain:
#   restore = latest full + the newest diff made from that full.
#
# Runs daily from cron but only does work when something is due, so failures retry next day.
# No secrets are stored here: the AWS key comes from the TrueNAS cloud credential and the
# encryption password/salt from the "offsite: isaac" Cloud Sync task, read at runtime as root.
# Objects: s3://<bucket>/zvol/ (rclone crypt, standard filename encryption, DEEP_ARCHIVE).
set -euo pipefail

notify_fail() {
    msg="$(basename "$0") failed on $(hostname) at line ${1:-?}. See: grep $(basename "$0" .sh) /var/log/syslog"
    logger -t "$(basename "$0" .sh)" "ERROR: $msg"
    midclt call mail.send "$(jq -nc --arg s "[TrueNAS] $(basename "$0") FAILED" --arg t "$msg" \
        '{subject:$s, text:$t, to:["alerts@example.com"]}')" >/dev/null || true
}
trap 'notify_fail $LINENO' ERR

ZVOL=datastore/NAS/nas
BUCKET=example-homelab-offsite
CRYPT_TASK="offsite: isaac"
FULL_EVERY_DAYS=180
DIFF_EVERY_DAYS=28
STATE=/mnt/datastore/backups/.offsite
ZFS=/usr/sbin/zfs
TODAY=$(date +%Y%m%d)
NOW=$(date +%s)

log() { logger -t zvol-offsite "$*"; echo "$*"; }
age_days() { echo $(( (NOW - $1) / 86400 )); }

exec 9>"$STATE/zvol-offsite.lock"
flock -n 9 || { echo "already running"; exit 0; }

# ---- decide what is due ------------------------------------------------------
base=$($ZFS list -H -t snapshot -o name -s creation "$ZVOL" | grep "@offsite-base-" | tail -1 || true)
mode=""
if [ -z "$base" ]; then
    mode=full
elif [ "$(age_days "$($ZFS get -Hp -o value creation "$base")")" -ge "$FULL_EVERY_DAYS" ]; then
    mode=full
else
    last=0; [ -f "$STATE/zvol-last-success" ] && last=$(stat -c %Y "$STATE/zvol-last-success")
    [ "$(age_days "$last")" -ge "$DIFF_EVERY_DAYS" ] && mode=diff
fi
[ -n "$mode" ] || { echo "nothing due"; exit 0; }

# ---- rclone config in environment only ----------------------------------------
cred=$(midclt call cloudsync.credentials.query '[["name","^","aws-offsite"]]' | jq -c '.[0].provider')
task=$(midclt call cloudsync.query "[[\"description\",\"=\",\"$CRYPT_TASK\"]]" | jq -c '.[0]')
[ "$cred" != "null" ] && [ "$task" != "null" ] || { log "ERROR: credential or crypt task missing"; exit 1; }

export RCLONE_CONFIG_S3_TYPE=s3 RCLONE_CONFIG_S3_PROVIDER=AWS RCLONE_CONFIG_S3_REGION=us-east-1
export RCLONE_CONFIG_S3_STORAGE_CLASS=DEEP_ARCHIVE RCLONE_CONFIG_S3_NO_CHECK_BUCKET=true
RCLONE_CONFIG_S3_ACCESS_KEY_ID=$(echo "$cred" | jq -r .access_key_id);         export RCLONE_CONFIG_S3_ACCESS_KEY_ID
RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=$(echo "$cred" | jq -r .secret_access_key); export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY
export RCLONE_CONFIG_SEC_TYPE=crypt RCLONE_CONFIG_SEC_REMOTE="s3:$BUCKET/zvol" RCLONE_CONFIG_SEC_FILENAME_ENCRYPTION=standard
RCLONE_CONFIG_SEC_PASSWORD=$(echo "$task" | jq -r .encryption_password | rclone obscure -);  export RCLONE_CONFIG_SEC_PASSWORD
RCLONE_CONFIG_SEC_PASSWORD2=$(echo "$task" | jq -r .encryption_salt | rclone obscure -);    export RCLONE_CONFIG_SEC_PASSWORD2

# 256 MiB parts x 10,000 parts max = 2.5 TiB stream limit (zvol is 2 TiB).
# Full speed 00:00-07:00, ~50 Mbit/s during the day.
RCAT=(rclone rcat --config /dev/null --s3-chunk-size 256M --s3-upload-concurrency 4 --bwlimit "00:00,off 07:00,6250000b")

# ---- full ----------------------------------------------------------------------
if [ "$mode" = full ]; then
    new="$ZVOL@offsite-base-$TODAY"
    $ZFS snapshot "$new"
    $ZFS hold offsite "$new"
    log "full stream of $new starting"
    if $ZFS send -c "$new" | "${RCAT[@]}" "sec:full-$TODAY.zfs"; then
        for old in $($ZFS list -H -t snapshot -o name "$ZVOL" | grep "@offsite-base-" | grep -vx "$new"); do
            $ZFS release offsite "$old" && $ZFS destroy "$old"
        done
        touch "$STATE/zvol-last-success"
        log "full stream $TODAY uploaded; new base $new"
    else
        $ZFS release offsite "$new"; $ZFS destroy "$new"
        log "ERROR: full upload failed; kept previous base"; notify_fail full-upload; exit 1
    fi
# ---- differential --------------------------------------------------------------
else
    snap="$ZVOL@offsite-diff-$TODAY"
    $ZFS snapshot "$snap"
    trap '$ZFS destroy "$snap" 2>/dev/null || true' EXIT
    basedate=${base##*@offsite-base-}
    log "diff stream $basedate -> $TODAY starting"
    $ZFS send -c -i "$base" "$snap" | "${RCAT[@]}" "sec:diff-$basedate-$TODAY.zfs"
    touch "$STATE/zvol-last-success"
    log "diff stream $basedate -> $TODAY uploaded"
fi
