#!/usr/bin/env bash
set -euo pipefail
umask 022

OUT_DIR="/var/www/internal/goaccess"
OUT_FILE="${OUT_DIR}/index.html"
TMP_FILE="${OUT_DIR}/index.html.tmp"

install -d -m 0755 "$OUT_DIR"

shopt -s nullglob
logs=(/var/log/nginx/access.log /var/log/nginx/access.log.1 /var/log/nginx/access.log.*.gz)

if [ "${#logs[@]}" -eq 0 ]; then
    printf '<!doctype html><title>GoAccess</title><p>No Nginx access logs yet.</p>\n' > "$TMP_FILE"
    mv "$TMP_FILE" "$OUT_FILE"
    exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
combined="${workdir}/access.combined.log"

zcat -f "${logs[@]}" > "$combined"

if [ -s "$combined" ]; then
    goaccess "$combined" \
        --log-format=COMBINED \
        --no-global-config \
        --html-report-title="marcelwalder.eu Nginx Traffic & Bot Analytics" \
        -o "$TMP_FILE"
    chmod 0644 "$TMP_FILE"
    mv "$TMP_FILE" "$OUT_FILE"
else
    printf '<!doctype html><title>GoAccess</title><p>Access log is empty.</p>\n' > "$TMP_FILE"
    chmod 0644 "$TMP_FILE"
    mv "$TMP_FILE" "$OUT_FILE"
fi
