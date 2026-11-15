#!/usr/bin/env bash
set -uo pipefail

RECIPIENT="${UPDATE_NOTIFY_RECIPIENT:-marcelwalder12@gmail.com}"
LOG_FILE="/var/log/mailserver-update.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "Starting System & Stack Update: $(date)"
echo "=================================================="

send_notification() {
    local subject="$1"
    local body="$2"
    docker exec -i mailserver sendmail -f info@marcelwalder.eu "$RECIPIENT" <<MAIL_EOF || true
From: info@marcelwalder.eu
To: $RECIPIENT
Subject: $subject
Date: $(date -R)

$body
MAIL_EOF
}

HEALTH_OK=true
ERROR_MSG=""
UPDATES_MADE=""

# 1. Update Host OS Packages (Nginx, GoAccess, Fail2ban, WireGuard, node_exporter, nftables, OS security updates)
echo "[1/6] Updating Ubuntu packages..."
export DEBIAN_FRONTEND=noninteractive
if ! apt-get update -q || ! apt-get upgrade -y -q; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}apt-get update/upgrade failed.\n"
fi
apt-get autoremove -y -q || true
apt-get clean || true

# 2. Check & Update Docker-Mailserver
echo "[2/6] Checking Docker-Mailserver updates..."
OLD_DMS_IMAGE=$(docker inspect --format='{{.Image}}' mailserver 2>/dev/null || echo "none")
if [ -f /opt/mailserver/docker-compose.yml ]; then
    docker compose -f /opt/mailserver/docker-compose.yml pull -q || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to pull Docker-Mailserver image.\n"
    }
    docker compose -f /opt/mailserver/docker-compose.yml up -d || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to start Docker-Mailserver container.\n"
    }
fi
NEW_DMS_IMAGE=$(docker inspect --format='{{.Image}}' mailserver 2>/dev/null || echo "none")
if [ "$OLD_DMS_IMAGE" != "$NEW_DMS_IMAGE" ]; then
    UPDATES_MADE="${UPDATES_MADE}- Docker-Mailserver updated\n"
fi

# 3. Check & Update SnappyMail
echo "[3/6] Checking SnappyMail updates..."
OLD_SNAPPY_IMAGE=$(docker inspect --format='{{.Image}}' snappymail 2>/dev/null || echo "none")
if [ -f /opt/snappymail/docker-compose.yml ]; then
    docker compose -f /opt/snappymail/docker-compose.yml pull -q || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to pull SnappyMail image.\n"
    }
    docker compose -f /opt/snappymail/docker-compose.yml up -d || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to start SnappyMail container.\n"
    }
fi
NEW_SNAPPY_IMAGE=$(docker inspect --format='{{.Image}}' snappymail 2>/dev/null || echo "none")
if [ "$OLD_SNAPPY_IMAGE" != "$NEW_SNAPPY_IMAGE" ]; then
    UPDATES_MADE="${UPDATES_MADE}- SnappyMail updated\n"
fi

# 4. Check & Update Uptime Kuma (pinned major tag :2 with pre-upgrade snapshot)
echo "[4/6] Checking Uptime Kuma updates..."
OLD_KUMA_IMAGE=$(docker inspect --format='{{.Image}}' uptime-kuma 2>/dev/null || echo "none")
KUMA_BACKUP="/var/backups/uptime-kuma-pre-upgrade.tar.gz"
KUMA_UPGRADED=false
if [ -f /opt/uptime-kuma/compose.yml ]; then
    if docker compose -f /opt/uptime-kuma/compose.yml pull -q; then
        PULLED_KUMA_IMAGE=$(docker image inspect --format='{{.Id}}' louislam/uptime-kuma:2 2>/dev/null || echo "none")
        if [ "$OLD_KUMA_IMAGE" != "$PULLED_KUMA_IMAGE" ]; then
            install -d -m 0700 /var/backups
            tar -czf "$KUMA_BACKUP" -C /opt/uptime-kuma data
            docker compose -f /opt/uptime-kuma/compose.yml down
            docker compose -f /opt/uptime-kuma/compose.yml up -d --remove-orphans || {
                HEALTH_OK=false
                ERROR_MSG="${ERROR_MSG}Failed to recreate Uptime Kuma container.\n"
            }
            KUMA_UPGRADED=true
        else
            docker compose -f /opt/uptime-kuma/compose.yml up -d --remove-orphans >/dev/null 2>&1 || true
        fi
    else
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to pull Uptime Kuma image.\n"
    fi
fi
NEW_KUMA_IMAGE=$(docker inspect --format='{{.Image}}' uptime-kuma 2>/dev/null || echo "none")
if [ "$OLD_KUMA_IMAGE" != "$NEW_KUMA_IMAGE" ]; then
    UPDATES_MADE="${UPDATES_MADE}- Uptime Kuma (:2) updated\n"
fi

# 5. Health Check Verification
echo "[5/6] Verifying stack health..."
sleep 10

DMS_STATUS=$(docker inspect --format='{{.State.Status}}' mailserver 2>/dev/null || echo "dead")
if [ "$DMS_STATUS" != "running" ]; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}Docker-Mailserver is not running (Status: $DMS_STATUS).\n"
fi

SNAPPY_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8888/ || echo "000")
if [ "$SNAPPY_HTTP" != "200" ]; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}SnappyMail returned HTTP $SNAPPY_HTTP.\n"
fi

KUMA_HTTP="000"
for _ in $(seq 1 12); do
    KUMA_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/ || echo "000")
    if [ "$KUMA_HTTP" = "200" ] || [ "$KUMA_HTTP" = "302" ]; then
        break
    fi
    sleep 5
done
if [ "$KUMA_HTTP" != "200" ] && [ "$KUMA_HTTP" != "302" ]; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}Uptime Kuma returned HTTP $KUMA_HTTP.\n"
elif [ "$KUMA_UPGRADED" = true ] && [ -f "$KUMA_BACKUP" ]; then
    rm -f "$KUMA_BACKUP"
fi

for svc in nginx fail2ban prometheus-node-exporter wg-quick@wg0; do
    if ! systemctl is-active --quiet "$svc"; then
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Systemd service ${svc} is not active.\n"
    fi
done

METRICS_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9100/metrics || echo "000")
if [ "$METRICS_HTTP" != "200" ]; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}node_exporter /metrics returned HTTP $METRICS_HTTP.\n"
fi

if ! nft list table inet marcelwalder_geoblock >/dev/null 2>&1; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}nftables table inet marcelwalder_geoblock is not loaded.\n"
fi

# 6. Disk Cleanup & Reporting
echo "[6/6] Performing cleanup and notification..."
docker image prune -f || true

MEM_INFO=$(free -m | awk '/Mem:/ {printf "%sMB / %sMB (%.1f%%)", $3, $2, $3/$2*100}')
DISK_INFO=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
REBOOT_REQUIRED="No"
if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED="Yes (kernel/system reboot pending)"
fi

if [ "$HEALTH_OK" = true ]; then
    echo "Update completed successfully! All services healthy."
    if [ -n "$UPDATES_MADE" ] || [ -f /var/run/reboot-required ]; then
        CHANGES=$(printf "%b" "${UPDATES_MADE:-No container images changed.\n}")
        send_notification "[SUCCESS] Mail Server Automated Update Completed" "Automated update ran successfully on mail.marcelwalder.eu.

${CHANGES}
System Status:
- Memory: $MEM_INFO
- Boot Disk: $DISK_INFO
- Reboot Required: $REBOOT_REQUIRED
- Mailserver: Running
- SnappyMail: HTTP $SNAPPY_HTTP
- Uptime Kuma: HTTP $KUMA_HTTP
- Nginx / Fail2ban / WireGuard / Geoblock / node_exporter: Active"
    fi
else
    echo "CRITICAL: Post-update health check failed!"
    printf "%b" "$ERROR_MSG"
    send_notification "[CRITICAL ALERT] Mail Server Update Health Check Failed" "Warning: An issue was detected following the automated update routine on mail.marcelwalder.eu.

Error details:
$(printf "%b" "$ERROR_MSG")
System Status:
- Memory: $MEM_INFO
- Boot Disk: $DISK_INFO
- Reboot Required: $REBOOT_REQUIRED

Inspect logs via SSH:
ssh ubuntu@92.5.85.159 'sudo tail -n 100 /var/log/mailserver-update.log'"
    exit 1
fi

echo "Update routine completed at $(date)"
