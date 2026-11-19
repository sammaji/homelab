#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl make git nginx certbot python3-certbot-dns-cloudflare

if ! command -v docker >/dev/null 2>&1; then
    echo "INFO: Installing Docker Engine from Docker's apt repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo systemctl enable --now docker nginx

if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    echo "INFO: Added $USER to the docker group - log out and back in for it to apply."
fi

docker --version || sudo docker --version
nginx -v
certbot --version
echo "INFO: Host setup complete."
