#!/usr/bin/env bash
set -euo pipefail
umask 077

BACKUP_DIR="/backup"
DATE=$(date +"%Y%m%d-%H%M")
ARCHIVE_NAME="mailserver-backup-${DATE}.tar.gz"
TARGET="${BACKUP_DIR}/${ARCHIVE_NAME}"
KEEP_DAYS=7

install -d -m 0700 -o root -g root "$BACKUP_DIR"

echo "=== Mailserver Backup: $(date) ==="
echo "Creating archive: $TARGET"

tar -czf "$TARGET" \
    -C / \
    opt/mailserver/mail-data \
    opt/mailserver/config \
    opt/mailserver/docker-compose.yml \
    opt/mailserver/mailserver.env \
    opt/snappymail/volume \
    opt/snappymail/docker-compose.yml \
    etc/letsencrypt \
    etc/nginx \
    var/www/mail \
    var/www/mta-sts \
    opt/quota-watchdog.sh \
    opt/mailserver-update.sh

chmod 0600 "$TARGET"

SIZE=$(du -h "$TARGET" | awk '{print $1}')
echo "Backup created successfully! Size: $SIZE"

# Prune archives older than KEEP_DAYS
echo "Pruning backups older than $KEEP_DAYS days..."
find "$BACKUP_DIR" -type f -name "mailserver-backup-*.tar.gz" -mtime +$KEEP_DAYS -delete

TOTAL_BACKUPS=$(ls -1 "$BACKUP_DIR"/mailserver-backup-*.tar.gz 2>/dev/null | wc -l)
echo "Current backups in $BACKUP_DIR: $TOTAL_BACKUPS"
echo "=== Backup Complete ==="
