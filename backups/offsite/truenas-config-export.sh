#!/bin/bash
# truenas-config-export.sh - weekly TrueNAS config export (incl. secret seed).
# Builds the same tar the web UI's "Download configuration (with secret seed)" produces:
# a consistent SQLite copy of /data/freenas-v1.db plus /data/pwenc_secret.
# Lands in /mnt/datastore/backups/truenas-config/, which the "offsite: backups"
# Cloud Sync task uploads (encrypted) to S3. Keeps the newest 8 exports.
set -euo pipefail

notify_fail() {
    msg="$(basename "$0") failed on $(hostname) at line ${1:-?}. See: grep $(basename "$0" .sh) /var/log/syslog"
    logger -t "$(basename "$0" .sh)" "ERROR: $msg"
    midclt call mail.send "$(jq -nc --arg s "[TrueNAS] $(basename "$0") FAILED" --arg t "$msg" \
        '{subject:$s, text:$t, to:["alerts@example.com"]}')" >/dev/null || true
}
trap 'notify_fail $LINENO' ERR
DEST=/mnt/datastore/backups/truenas-config
mkdir -p "$DEST" && chmod 700 "$DEST"

ver=$(midclt call system.info | jq -r .version)
f="$DEST/truenas-config-${ver}-$(date +%Y%m%d-%H%M).tar"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

sqlite3 /data/freenas-v1.db ".backup '$tmp/freenas-v1.db'"
[ "$(sqlite3 "$tmp/freenas-v1.db" 'PRAGMA integrity_check;')" = ok ]
cp /data/pwenc_secret "$tmp/pwenc_secret"
tar -C "$tmp" -cf "$f.part" freenas-v1.db pwenc_secret
mv "$f.part" "$f" && chmod 600 "$f"

ls -1t "$DEST"/truenas-config-*.tar | tail -n +9 | xargs -r rm -f
logger -t truenas-config-export "saved $(basename "$f")"
