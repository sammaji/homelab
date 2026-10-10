#!/usr/bin/env bash
# Idempotent ufw baseline for the VPS: public 22/80/443 + Tailscale, deny everything
# else. Run on the VPS itself (via `make ufw-apply`) after `tailscale up` has already
# created the tailscale0 interface - the "allow in on tailscale0" rule needs it to exist.

set -euo pipefail

if ! command -v ufw >/dev/null 2>&1; then
    echo "INFO: ufw not found, installing..."
    sudo apt-get update && sudo apt-get install -y ufw
fi

if ! ip link show tailscale0 >/dev/null 2>&1; then
    echo "ERROR: tailscale0 interface not found. Run 'sudo tailscale up' first." >&2
    exit 1
fi

echo "INFO: Applying ufw baseline..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'nginx HTTP'
sudo ufw allow 443/tcp comment 'nginx HTTPS'
sudo ufw allow 41641/udp comment 'tailscale direct connections'
sudo ufw allow in on tailscale0 comment 'trust all traffic from the tailnet'

sudo ufw --force enable
sudo ufw status verbose
