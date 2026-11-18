#!/usr/bin/env bash
set -uo pipefail

UNIT="${1:-unknown.service}"
HOST="$(hostname -f 2>/dev/null || hostname)"
STATUS_OUT="$(systemctl status "$UNIT" --no-pager -l 2>&1 | tail -n 25 || true)"
JOURNAL_OUT="$(journalctl -u "$UNIT" -n 30 --no-pager 2>&1 || true)"

BODY="Systemd unit '${UNIT}' failed on ${HOST} at $(date -R).

=== systemctl status ${UNIT} ===
${STATUS_OUT}

=== journalctl -u ${UNIT} (last 30 lines) ===
${JOURNAL_OUT}"

/usr/local/sbin/marcelwalder-send-alert "[CRITICAL ALERT] Systemd Unit Failed: ${UNIT} (${HOST})" "$BODY"
