SHELL := /bin/bash

NGINX_SRC      := $(CURDIR)/nginx
NGINX_SITES    := /etc/nginx/sites-available
NGINX_CONF_D   := /etc/nginx/conf.d
NGINX_SNIPPETS := /etc/nginx/snippets

# Set USE_INFISICAL=1 in prod environment to inject secrets via Infisical CLI.
# Locally, leave unset - docker compose reads from .env as usual.
USE_INFISICAL ?= 0
INFISICAL_ENV ?= prod

ifeq ($(USE_INFISICAL), 1)
  INFISICAL_RUN := infisical run --env=$(INFISICAL_ENV) --
else
  INFISICAL_RUN :=
endif

.PHONY: help init nginx-certs nginx-link nginx-apply ufw-apply tailnet-hosts \
        infisical-up infisical-down infisical-ps infisical-logs infisical-restart

# Domains restricted to tailnet-only access (see nginx/snippets/tailnet-only.conf).
# Keep in sync with which vhosts include that snippet.
TAILNET_DOMAINS := grafana.sammaji.com infisical.sammaji.com

# Domains this host serves; nginx-certs issues one Let's Encrypt cert per domain
# (the vhosts reference /etc/letsencrypt/live/<domain>/). DNS-01 via Cloudflare, so no
# public port 80 is needed - works on a tailnet-only host.
CERT_DOMAINS   := bifrost.sammaji.com grafana.sammaji.com infisical.sammaji.com jellyfin.sammaji.com \
                  listmonk.sammaji.com n8n.sammaji.com
CERTBOT_EMAIL  ?=
CLOUDFLARE_INI := /etc/letsencrypt/cloudflare.ini


# ── Pattern rules ──
%-up:
	cd $* && $(INFISICAL_RUN) docker compose up -d

%-down:
	cd $* && $(INFISICAL_RUN) docker compose down

%-ps:
	cd $* && $(INFISICAL_RUN) docker compose ps

%-logs:
	cd $* && $(INFISICAL_RUN) docker compose logs -f

%-restart:
	cd $* && $(INFISICAL_RUN) docker compose restart


# ── Infisical (always uses .env — it IS the secret store) ──
infisical-up:
	cd infisical && docker compose up -d

infisical-down:
	cd infisical && docker compose down

infisical-ps:
	cd infisical && docker compose ps

infisical-logs:
	cd infisical && docker compose logs -f

infisical-restart:
	cd infisical && docker compose restart


# ── Init ──
init:
	@echo "Initializing environment..."
	@./scripts/create_symlinks.sh


# ── Nginx ──
nginx-link:
	@if [ -d "$(NGINX_SITES).bak" ]; then \
		printf "$(NGINX_SITES).bak already exists. Overwrite backup? [y/N] "; \
		read ans; \
		[[ "$$ans" == [yY] ]] || { echo "Aborted."; exit 0; }; \
	fi
	@sudo cp -r $(NGINX_SITES) $(NGINX_SITES).bak
	@echo "Backed up $(NGINX_SITES) -> $(NGINX_SITES).bak"
	@sudo cp $(NGINX_SRC)/sites-available/* $(NGINX_SITES)/
	@echo "Copied sites-available"
	@sudo mkdir -p $(NGINX_SNIPPETS) && sudo cp $(NGINX_SRC)/snippets/* $(NGINX_SNIPPETS)/
	@echo "Copied snippets"
	@sudo cp $(NGINX_SRC)/conf.d/* $(NGINX_CONF_D)/
	@echo "Copied conf.d"
	@sudo sed -i -E 's/^(\s*)(ssl_protocols|ssl_prefer_server_ciphers)(\s)/\1# \2\3/' /etc/nginx/nginx.conf
	@echo "Commented out ssl_protocols/ssl_prefer_server_ciphers in nginx.conf (ssl-global.conf sets them)"
	@echo "Relinking sites-enabled..."
	@sudo rm -f /etc/nginx/sites-enabled/*
	@for f in $(NGINX_SITES)/*; do \
		sudo ln -s "$$f" /etc/nginx/sites-enabled/$$(basename "$$f"); \
		echo "  Linked $$(basename $$f)"; \
	done
	@echo "Done. Run 'make nginx-apply' to test and reload."

nginx-certs:
	@test -n "$(CERTBOT_EMAIL)" || { echo "Usage: make nginx-certs CERTBOT_EMAIL=you@example.com"; exit 1; }
	@sudo test -f $(CLOUDFLARE_INI) || { \
		echo "Missing $(CLOUDFLARE_INI). Create it with a Cloudflare token scoped to Zone:DNS:Edit:"; \
		echo "  sudo mkdir -p /etc/letsencrypt && echo 'dns_cloudflare_api_token = <token>' | sudo tee $(CLOUDFLARE_INI) >/dev/null && sudo chmod 600 $(CLOUDFLARE_INI)"; \
		exit 1; }
	@sudo apt-get install -y -qq certbot python3-certbot-dns-cloudflare >/dev/null
	@sudo test -f /etc/letsencrypt/ssl-dhparams.pem || { \
		echo "Generating /etc/letsencrypt/ssl-dhparams.pem (referenced by conf.d/ssl-global.conf)..."; \
		sudo openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048; }
	@for d in $(CERT_DOMAINS); do \
		sudo certbot certonly --non-interactive --agree-tos -m "$(CERTBOT_EMAIL)" \
			--dns-cloudflare --dns-cloudflare-credentials $(CLOUDFLARE_INI) \
			--dns-cloudflare-propagation-seconds 30 --keep-until-expiring -d "$$d" \
			--deploy-hook "systemctl reload nginx || true" \
			|| exit 1; \
	done
	@echo "Certs ready. certbot's systemd timer renews them and reloads nginx (deploy hook)."

nginx-apply:
	@sudo nginx -t || { echo "nginx -t failed, aborting."; exit 1; }
	@printf "nginx -t passed. Restart nginx? [y/N] "; \
	read ans; \
	[[ "$$ans" == [yY] ]] || { echo "Aborted."; exit 0; }; \
	sudo systemctl restart nginx; \
	echo "nginx restarted."


# ── Tailscale / firewall (run on the VPS; requires 'tailscale up' first) ──
ufw-apply:
	@./scripts/setup-ufw.sh


# ── Tailnet-only DNS override (run on client devices, not the VPS) ──
tailnet-hosts:
	@test -n "$(TAILSCALE_VPS_IP)" || { echo "Usage: make tailnet-hosts TAILSCALE_VPS_IP=100.x.x.x"; exit 1; }
	@./scripts/tailnet-hosts.sh $(TAILSCALE_VPS_IP) $(TAILNET_DOMAINS)


# ── Help ──
help:
	@echo "Usage: [USE_INFISICAL=1] [INFISICAL_ENV=prod] make <target>"
	@echo ""
	@echo "Secret injection:"
	@echo "  USE_INFISICAL=1   Wrap docker compose with 'infisical run' (set in VPS env)"
	@echo "  INFISICAL_ENV     Infisical environment to use (default: prod)"
	@echo ""
	@echo "Initialization:"
	@echo "  make init             - Setup .env and create symlinks"
	@echo ""
	@echo "Nginx:"
	@echo "  make nginx-certs CERTBOT_EMAIL=you@x.com - Issue Let's Encrypt certs for CERT_DOMAINS via Cloudflare DNS-01 (run before nginx-apply)"
	@echo "  make nginx-link       - Backup /etc/nginx/sites-available and deploy nginx/ configs"
	@echo "  make nginx-apply      - Test nginx config; if ok, restart nginx"
	@echo ""
	@echo "Tailscale / firewall:"
	@echo "  make ufw-apply                              - (on VPS) Apply the ufw baseline: 22/80/443 public, rest tailnet-only"
	@echo "  make tailnet-hosts TAILSCALE_VPS_IP=100.x.x.x - (on client devices) Map tailnet-only domains to the VPS's Tailscale IP in /etc/hosts"
	@echo ""
	@echo "Pattern rules (replace <stack> with folder name, e.g. monitoring):"
	@echo "  make <stack>-up       - Start stack (uses Infisical if USE_INFISICAL=1)"
	@echo "  make <stack>-down     - Stop stack"
	@echo "  make <stack>-ps       - List running containers"
	@echo "  make <stack>-logs     - Stream logs"
	@echo "  make <stack>-restart  - Restart stack"
	@echo ""
	@echo "Infisical stack (always uses .env, never Infisical CLI):"
	@echo "  make infisical-up / down / ps / logs / restart"
