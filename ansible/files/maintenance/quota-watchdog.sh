#!/usr/bin/env bash
set -uo pipefail

RECIPIENT="marcelwalder12@gmail.com"
RELAY_LIMIT=3000
RELAY_70=2100
RELAY_90=2700

send_alert() {
    local subject="$1"
    local body="$2"
    ALERT_RECIPIENT="$RECIPIENT" /usr/local/sbin/marcelwalder-send-alert "$subject" "$body" || true
}

# 1. Monthly Relay Volume Check
CURRENT_MONTH=$(date +"%b")
LOG_FILE="/opt/mailserver/mail-logs/mail.log"

SENT_COUNT=0
if [ -f "$LOG_FILE" ]; then
    CNT=$(grep "$CURRENT_MONTH" "$LOG_FILE" 2>/dev/null | grep -c "relay=smtp.email.eu-frankfurt-1.oci.oraclecloud.com.*status=sent" || true)
    if [ -n "$CNT" ]; then
        SENT_COUNT=$CNT
    fi
fi

# 2. Disk Usage Check (50 GB Boot Volume)
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

# 3. Memory Usage Check for OCI Always Free Idle Reclaim Rule (Threshold 20%)
MEM_USED_MB=$(free -m | awk '/Mem:/ {print $3}')
MEM_TOTAL_MB=$(free -m | awk '/Mem:/ {print $2}')
MEM_PERCENT=$(( 100 * MEM_USED_MB / MEM_TOTAL_MB ))
IDLE_STATE_FILE="/opt/mailserver/idle_mem_hours.count"

echo "=== Watchdog Run: $(date) ==="
echo "Monthly Relay Emails Sent: $SENT_COUNT / $RELAY_LIMIT"
echo "Root Disk Usage: ${DISK_PERCENT}%"
echo "Memory Usage: ${MEM_PERCENT}% (${MEM_USED_MB}MB / ${MEM_TOTAL_MB}MB)"

# Relay alerts
if [ "$SENT_COUNT" -ge "$RELAY_90" ]; then
    send_alert "CRITICAL: OCI Email Relay at 90% ($SENT_COUNT / $RELAY_LIMIT)" "You have sent $SENT_COUNT emails this month out of your 3,000 Always Free allowance."
elif [ "$SENT_COUNT" -ge "$RELAY_70" ]; then
    send_alert "WARNING: OCI Email Relay at 70% ($SENT_COUNT / $RELAY_LIMIT)" "You have sent $SENT_COUNT emails this month out of your 3,000 Always Free allowance."
fi

# Disk alerts
if [ "$DISK_PERCENT" -ge 90 ]; then
    send_alert "CRITICAL: Mail Server Disk at ${DISK_PERCENT}%" "Your 50 GB boot volume is at ${DISK_PERCENT}% capacity."
elif [ "$DISK_PERCENT" -ge 70 ]; then
    send_alert "WARNING: Mail Server Disk at ${DISK_PERCENT}%" "Your 50 GB boot volume is at ${DISK_PERCENT}% capacity."
fi

# Memory Idle Reclaim alerts
if [ "$MEM_PERCENT" -lt 20 ]; then
    PREV=0
    if [ -f "$IDLE_STATE_FILE" ]; then
        PREV=$(cat "$IDLE_STATE_FILE")
    fi
    CURRENT=$(( PREV + 1 ))
    echo "$CURRENT" > "$IDLE_STATE_FILE"
    echo "Memory below 20% threshold! Count: $CURRENT consecutive hours"

    if [ "$CURRENT" -ge 6 ]; then
        send_alert "CRITICAL: Mail Server Memory Below 20% for ${CURRENT}h (Reclaim Risk)" "Warning: Memory utilization on your Always Free instance has been ${MEM_PERCENT}% for ${CURRENT} consecutive hours. Oracle Always Free VMs are subject to reclamation if CPU, Network, and Memory all remain under 20% for 7 days. Please check your VM and verify Docker-Mailserver is running."
    fi
else
    echo "0" > "$IDLE_STATE_FILE"
fi
