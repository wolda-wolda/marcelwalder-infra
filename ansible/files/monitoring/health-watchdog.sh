#!/usr/bin/env bash
set -uo pipefail

STATE_DIR="/var/lib/marcelwalder"
STATE_FILE="${STATE_DIR}/health-alert.state"
install -d -m 0700 -o root -g root "$STATE_DIR"

FAILURES=()
HEALED=()

# 1. Critical systemd services
for svc in nginx docker fail2ban prometheus-node-exporter wg-quick@wg0; do
    if ! systemctl is-active --quiet "$svc"; then
        systemctl restart "$svc" >/dev/null 2>&1 || true
        sleep 3
        if systemctl is-active --quiet "$svc"; then
            HEALED+=("Systemd service '${svc}' was down and automatically restarted.")
        else
            FAILURES+=("Systemd service '${svc}' is DOWN and failed to restart.")
        fi
    fi
done

# 2. Docker-Mailserver container
DMS_STATE="$(docker inspect --format='{{.State.Status}}' mailserver 2>/dev/null || echo 'missing')"
if [ "$DMS_STATE" != "running" ]; then
    if [ -f /opt/mailserver/docker-compose.yml ]; then
        docker compose -f /opt/mailserver/docker-compose.yml up -d >/dev/null 2>&1 || true
        sleep 5
    fi
    DMS_STATE="$(docker inspect --format='{{.State.Status}}' mailserver 2>/dev/null || echo 'missing')"
    if [ "$DMS_STATE" = "running" ]; then
        HEALED+=("Container 'mailserver' was not running and was automatically started.")
    else
        FAILURES+=("Container 'mailserver' is NOT running (state: ${DMS_STATE}).")
    fi
fi

# 3. SnappyMail HTTP backend (127.0.0.1:8888)
SNAPPY_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8888/ || echo '000')"
if [ "$SNAPPY_CODE" != "200" ]; then
    if [ -f /opt/snappymail/docker-compose.yml ]; then
        docker compose -f /opt/snappymail/docker-compose.yml up -d >/dev/null 2>&1 || true
        sleep 5
    fi
    SNAPPY_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8888/ || echo '000')"
    if [ "$SNAPPY_CODE" = "200" ]; then
        HEALED+=("SnappyMail (127.0.0.1:8888) was unresponsive and automatically recovered.")
    else
        FAILURES+=("SnappyMail (127.0.0.1:8888) returned HTTP ${SNAPPY_CODE}.")
    fi
fi

# 4. Uptime Kuma HTTP backend (127.0.0.1:3001)
KUMA_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3001/ || echo '000')"
if [ "$KUMA_CODE" != "200" ] && [ "$KUMA_CODE" != "302" ]; then
    if [ -f /opt/uptime-kuma/compose.yml ]; then
        docker compose -f /opt/uptime-kuma/compose.yml up -d >/dev/null 2>&1 || true
        sleep 8
    fi
    KUMA_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:3001/ || echo '000')"
    if [ "$KUMA_CODE" = "200" ] || [ "$KUMA_CODE" = "302" ]; then
        HEALED+=("Uptime Kuma (127.0.0.1:3001) was unresponsive and automatically recovered.")
    else
        FAILURES+=("Uptime Kuma (127.0.0.1:3001) returned HTTP ${KUMA_CODE}.")
    fi
fi

# 5. Prometheus node_exporter (127.0.0.1:9100/metrics)
METRICS_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:9100/metrics || echo '000')"
if [ "$METRICS_CODE" != "200" ]; then
    FAILURES+=("node_exporter (127.0.0.1:9100/metrics) returned HTTP ${METRICS_CODE}.")
fi

# 6. Geoblock nftables table
if ! nft list table inet marcelwalder_geoblock >/dev/null 2>&1; then
    systemctl start marcelwalder-geoblock.service >/dev/null 2>&1 || true
    if nft list table inet marcelwalder_geoblock >/dev/null 2>&1; then
        HEALED+=("nftables table 'inet marcelwalder_geoblock' was missing and restored.")
    else
        FAILURES+=("nftables table 'inet marcelwalder_geoblock' is missing and could not be restored.")
    fi
fi

PREV_STATE="OK"
if [ -f "$STATE_FILE" ]; then
    PREV_STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 'OK')"
fi

if [ "${#FAILURES[@]}" -gt 0 ]; then
    CURRENT_SIG="FAIL:$(printf '%s|' "${FAILURES[@]}")"
    if [ "$CURRENT_SIG" != "$PREV_STATE" ]; then
        printf '%s' "$CURRENT_SIG" > "$STATE_FILE"
        BODY="One or more critical services on mail.marcelwalder.eu failed health verification at $(date -R):

$(printf -- '- %s\n' "${FAILURES[@]}")"
        if [ "${#HEALED[@]}" -gt 0 ]; then
            BODY="${BODY}

Auto-healed during this check:
$(printf -- '- %s\n' "${HEALED[@]}")"
        fi
        /usr/local/sbin/marcelwalder-send-alert "[CRITICAL ALERT] Service Down on mail.marcelwalder.eu" "$BODY"
    fi
    exit 1
fi

if [ "${#HEALED[@]}" -gt 0 ]; then
    BODY="A transient service failure on mail.marcelwalder.eu was detected and automatically healed at $(date -R):

$(printf -- '- %s\n' "${HEALED[@]}")"
    /usr/local/sbin/marcelwalder-send-alert "[WARNING] Auto-Healed Service on mail.marcelwalder.eu" "$BODY"
fi

if [ "$PREV_STATE" != "OK" ]; then
    printf 'OK' > "$STATE_FILE"
    /usr/local/sbin/marcelwalder-send-alert "[RECOVERED] All Services Healthy on mail.marcelwalder.eu" \
        "All monitored services and endpoints on mail.marcelwalder.eu have recovered and passed health verification at $(date -R)."
fi
