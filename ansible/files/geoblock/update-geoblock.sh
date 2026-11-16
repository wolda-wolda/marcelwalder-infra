#!/usr/bin/env bash
set -euo pipefail
umask 022

CONF_FILE="/etc/marcelwalder/geoblock.conf"
NFT_DEST="/etc/marcelwalder/geoblock.nft"
NGINX_GEO_DIR="/etc/nginx/geo"
NGINX_GEO_DEST="${NGINX_GEO_DIR}/blocked-countries.inc"

COUNTRIES="ru by ir kp sy cu"
if [ -f "$CONF_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

v4_raw="$workdir/v4.raw"
v6_raw="$workdir/v6.raw"
: > "$v4_raw"
: > "$v6_raw"

for cc in $COUNTRIES; do
    cc_lower="$(printf '%s' "$cc" | tr '[:upper:]' '[:lower:]')"
    v4_url="https://www.ipdeny.com/ipblocks/data/aggregated/${cc_lower}-aggregated.zone"
    v6_url="https://www.ipdeny.com/ipv6/ipaddresses/aggregated/${cc_lower}-aggregated.zone"

    curl -fsSL --retry 2 --max-time 20 "$v4_url" \
        | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$' >> "$v4_raw"

    v6_tmp="$workdir/${cc_lower}.v6"
    http_code="$(curl -sSL --retry 2 --max-time 20 -w '%{http_code}' -o "$v6_tmp" "$v6_url")"
    if [ "$http_code" = "200" ]; then
        grep -E '^[0-9a-fA-F:]+/[0-9]{1,3}$' "$v6_tmp" >> "$v6_raw" || true
    elif [ "$http_code" != "404" ]; then
        echo "ERROR: Unexpected HTTP $http_code fetching $v6_url" >&2
        exit 1
    fi
done

sort -u "$v4_raw" > "$workdir/v4.sorted"
sort -u "$v6_raw" > "$workdir/v6.sorted"

if [ ! -s "$workdir/v4.sorted" ]; then
    echo "ERROR: No valid IPv4 CIDRs fetched; aborting before touching live rules." >&2
    exit 1
fi

nft_tmp="$workdir/geoblock.nft"
{
    echo "#!/usr/sbin/nft -f"
    echo "# Managed by marcelwalder-geoblock-update (countries: ${COUNTRIES})"
    echo "table inet marcelwalder_geoblock"
    echo "delete table inet marcelwalder_geoblock"
    echo ""
    echo "table inet marcelwalder_geoblock {"
    echo "    set blocked_v4 {"
    echo "        type ipv4_addr"
    echo "        flags interval"
    echo "        auto-merge"
    printf '        elements = {\n'
    sed 's/^/            /; $!s/$/,/' "$workdir/v4.sorted"
    echo "        }"
    echo "    }"
    echo ""
    echo "    set blocked_v6 {"
    echo "        type ipv6_addr"
    echo "        flags interval"
    echo "        auto-merge"
    if [ -s "$workdir/v6.sorted" ]; then
        printf '        elements = {\n'
        sed 's/^/            /; $!s/$/,/' "$workdir/v6.sorted"
        echo "        }"
    fi
    echo "    }"
    echo ""
    echo "    chain input {"
    echo "        type filter hook input priority filter - 10; policy accept;"
    echo "        ct state established,related accept"
    echo "        iifname \"lo\" accept"
    echo "        tcp dport { 22, 25, 80, 443, 465, 587, 993 } ip saddr @blocked_v4 counter drop"
    echo "        tcp dport { 22, 25, 80, 443, 465, 587, 993 } ip6 saddr @blocked_v6 counter drop"
    echo "    }"
    echo ""
    echo "    chain forward {"
    echo "        type filter hook forward priority filter - 10; policy accept;"
    echo "        ct state established,related accept"
    echo "        tcp dport { 25, 465, 587, 993 } ip saddr @blocked_v4 counter drop"
    echo "        tcp dport { 25, 465, 587, 993 } ip6 saddr @blocked_v6 counter drop"
    echo "    }"
    echo "}"
} > "$nft_tmp"

# Validate nftables ruleset before overwriting or loading
/usr/sbin/nft -c -f "$nft_tmp"

geo_tmp="$workdir/blocked-countries.inc"
{
    echo "# Managed by marcelwalder-geoblock-update (countries: ${COUNTRIES})"
    sed 's/$/ 1;/' "$workdir/v4.sorted"
    if [ -s "$workdir/v6.sorted" ]; then
        sed 's/$/ 1;/' "$workdir/v6.sorted"
    fi
} > "$geo_tmp"

# Apply nftables rules atomically
install -d -m 0755 "$(dirname "$NFT_DEST")"
install -m 0644 "$nft_tmp" "${NFT_DEST}.tmp"
mv "${NFT_DEST}.tmp" "$NFT_DEST"
/usr/sbin/nft -f "$NFT_DEST"

# Apply Nginx geo list atomically with rollback if nginx -t fails
if command -v nginx >/dev/null 2>&1; then
    install -d -m 0755 "$NGINX_GEO_DIR"
    had_prev=0
    if [ -f "$NGINX_GEO_DEST" ]; then
        cp -p "$NGINX_GEO_DEST" "$workdir/blocked-countries.inc.bak"
        had_prev=1
    fi
    install -m 0644 "$geo_tmp" "${NGINX_GEO_DEST}.tmp"
    mv "${NGINX_GEO_DEST}.tmp" "$NGINX_GEO_DEST"

    if ! nginx -t >/dev/null 2>&1; then
        echo "ERROR: nginx -t failed with updated geo list; rolling back." >&2
        if [ "$had_prev" -eq 1 ]; then
            mv "$workdir/blocked-countries.inc.bak" "$NGINX_GEO_DEST"
        fi
        exit 1
    fi
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    fi
fi

v4_count="$(wc -l < "$workdir/v4.sorted")"
v6_count="$(wc -l < "$workdir/v6.sorted")"
echo "Updated geoblock (${COUNTRIES}): ${v4_count} IPv4 CIDRs, ${v6_count} IPv6 CIDRs."
