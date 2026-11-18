#!/usr/bin/env bash
set -euo pipefail
umask 077

ENV_FILE="/etc/marcelwalder/restic.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Missing $ENV_FILE" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

candidates=(
    /opt/mailserver/mail-data
    /opt/mailserver/config
    /opt/mailserver/docker-compose.yml
    /opt/mailserver/mailserver.env
    /opt/snappymail/volume
    /opt/snappymail/docker-compose.yml
    /opt/uptime-kuma/data
    /etc/letsencrypt
    /etc/nginx
    /etc/marcelwalder
    /etc/wireguard
    /var/www/mail
    /var/www/mta-sts
    /opt/quota-watchdog.sh
    /opt/mailserver-update.sh
)

paths=()
for p in "${candidates[@]}"; do
    if [ -e "$p" ]; then
        paths+=("$p")
    fi
done

if [ "${#paths[@]}" -eq 0 ]; then
    echo "ERROR: No backup paths present." >&2
    exit 1
fi

if ! restic snapshots >/dev/null 2>&1; then
    echo "Initializing Restic repository in OCI Object Storage..."
    restic init
fi

restic backup \
    --one-file-system \
    --tag automated \
    --exclude-caches \
    --exclude='/opt/uptime-kuma/data/*.db-wal' \
    --exclude='/opt/uptime-kuma/data/*.db-shm' \
    "${paths[@]}"

restic forget \
    --prune \
    --keep-daily 14 \
    --keep-weekly 8 \
    --keep-monthly 6

HEARTBEAT_URL_FILE="/etc/marcelwalder/restic-heartbeat.url"
if [ -s "$HEARTBEAT_URL_FILE" ]; then
    HEARTBEAT_URL="$(cat "$HEARTBEAT_URL_FILE")"
    curl -fsS --max-time 10 "$HEARTBEAT_URL" >/dev/null || echo "WARN: Failed to ping Restic dead-man's-switch heartbeat" >&2
fi

echo "Restic encrypted offsite backup completed cleanly."
