#!/usr/bin/env bash
# Idempotently maps tailnet-only domains to the VPS's Tailscale IP in /etc/hosts, so
# requests to those domains route over the tailnet (where nginx allows them) instead
# of over the public internet (where nginx now returns 403 for them).
#
# Usage: scripts/tailnet-hosts.sh <tailscale-ip> <domain> [domain...]
# Typically invoked via `make tailnet-hosts TAILSCALE_VPS_IP=100.x.x.x`.
# Run this on each client device that needs admin access, not on the VPS.

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <tailscale-ip> <domain> [domain...]" >&2
    exit 1
fi

IP="$1"
shift
DOMAINS=("$@")

HOSTS_FILE="/etc/hosts"
MARK_START="# BEGIN homelab-tailnet (managed by scripts/tailnet-hosts.sh - do not edit by hand)"
MARK_END="# END homelab-tailnet"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

awk -v s="$MARK_START" -v e="$MARK_END" '
    $0 == s { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
' "$HOSTS_FILE" > "$TMP"

{
    cat "$TMP"
    echo "$MARK_START"
    for d in "${DOMAINS[@]}"; do
        echo "$IP $d"
    done
    echo "$MARK_END"
} | sudo tee "$HOSTS_FILE" > /dev/null

echo "INFO: Updated $HOSTS_FILE with ${#DOMAINS[@]} tailnet-only entries -> $IP"
printf '  %s\n' "${DOMAINS[@]}"
