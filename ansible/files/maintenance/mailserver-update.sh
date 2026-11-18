#!/usr/bin/env bash
set -uo pipefail

RECIPIENT="${UPDATE_NOTIFY_RECIPIENT:-marcelwalder12@gmail.com}"
LOG_FILE="/var/log/mailserver-update.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "Starting Host OS Update & Stack Health Check: $(date)"
echo "=================================================="

send_notification() {
    local subject="$1"
    local body="$2"
    ALERT_RECIPIENT="$RECIPIENT" /usr/local/sbin/marcelwalder-send-alert "$subject" "$body" || true
}

HEALTH_OK=true
ERROR_MSG=""
UPDATES_MADE=""

# 1. Update Host OS Packages (Nginx, GoAccess, Fail2ban, WireGuard, node_exporter, nftables, OS security updates)
echo "[1/6] Updating Ubuntu packages..."
export DEBIAN_FRONTEND=noninteractive
if ! apt-get update -q; then
    HEALTH_OK=false
    ERROR_MSG="${ERROR_MSG}apt-get update failed.\n"
else
    UPGRADABLE=$(apt-get -s upgrade | grep -c '^Inst ' || true)
    if ! apt-get upgrade -y -q; then
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}apt-get upgrade failed.\n"
    else
        if [ "$UPGRADABLE" -gt 0 ]; then
            UPDATES_MADE="${UPDATES_MADE}- Host OS packages upgraded (${UPGRADABLE})\n"
        fi
        if [ -f /etc/nginx/conf.d/default.conf ]; then
            rm -f /etc/nginx/conf.d/default.conf
        fi
        if [ -f /etc/logrotate.d/nginx ]; then
            sed -i -E 's/create[[:space:]]+[0-9]+[[:space:]]+nginx[[:space:]]+adm/create 640 www-data adm/' /etc/logrotate.d/nginx || true
        fi
        if nginx -t >/dev/null 2>&1; then
            systemctl reload nginx || true
        else
            HEALTH_OK=false
            ERROR_MSG="${ERROR_MSG}nginx -t configuration check failed after package upgrade.\n"
        fi
    fi
fi
apt-get autoremove -y -q || true
apt-get clean || true

# 2. Reconcile Docker-Mailserver (image digest pinned in GitOps Compose manifest)
echo "[2/6] Reconciling Docker-Mailserver..."
if [ -f /opt/mailserver/docker-compose.yml ]; then
    docker compose -f /opt/mailserver/docker-compose.yml up -d || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to ensure Docker-Mailserver container is running.\n"
    }
fi

# 3. Reconcile SnappyMail & apply Alpine security patches inside container
echo "[3/6] Reconciling SnappyMail..."
if [ -f /opt/snappymail/docker-compose.yml ]; then
    docker compose -f /opt/snappymail/docker-compose.yml up -d || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to ensure SnappyMail container is running.\n"
    }
fi
if docker inspect snappymail >/dev/null 2>&1; then
    docker exec snappymail sh -c 'apk update -q && apk upgrade --no-cache -q nginx libpq libecpg' >/dev/null 2>&1 || true
    if docker exec snappymail sh -c 'ls -l /proc/$(cat /tmp/nginx.pid)/exe' 2>/dev/null | grep -q '(deleted)'; then
        docker restart snappymail >/dev/null 2>&1 || true
    fi
fi

# 4. Reconcile Uptime Kuma (image digest pinned in GitOps Compose manifest)
echo "[4/6] Reconciling Uptime Kuma..."
if [ -f /opt/uptime-kuma/compose.yml ]; then
    docker compose -f /opt/uptime-kuma/compose.yml up -d --remove-orphans || {
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}Failed to ensure Uptime Kuma container is running.\n"
    }
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

for tbl in marcelwalder_host marcelwalder_geoblock; do
    if ! nft list table inet "$tbl" >/dev/null 2>&1; then
        HEALTH_OK=false
        ERROR_MSG="${ERROR_MSG}nftables table inet ${tbl} is not loaded.\n"
    fi
done

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
        CHANGES=$(printf "%b" "${UPDATES_MADE:-No host packages upgraded.\n}")
        send_notification "[SUCCESS] Mail Server Automated Update Completed" "Automated host maintenance ran successfully on mail.marcelwalder.eu.

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
