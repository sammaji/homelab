SHELL := /bin/bash

# ── Hosts ──
# Two VMs (terraform/oracle-vm): oracle-vm-hlab (my self-hosted services, tailnet-only)
# and oracle-vm-prod (public side-project traffic: 80/443 open). Pass ENV=hlab|prod;
# on a VM it defaults to that VM (from the hostname), anywhere else to "local", where
# the per-host checks are skipped and the nginx targets refuse to run.
ENV ?= $(patsubst oracle-vm-%,%,$(filter oracle-vm-%,$(shell hostname)))
ifeq ($(ENV),)
  ENV := local
endif
ifeq ($(filter $(ENV),hlab prod local),)
  $(error ENV must be hlab or prod, got "$(ENV)")
endif

PROD_STACKS := kai
stack_host   = $(if $(filter $(1),$(PROD_STACKS)),prod,hlab)
require_vm   = @[ "$(ENV)" != local ] || { echo "Pass ENV=hlab or ENV=prod (and run it on that VM)."; exit 1; }
check_host   = @[ "$(ENV)" = local ] || [ "$(ENV)" = "$(call stack_host,$(1))" ] || { 	echo "$(1) runs on oracle-vm-$(call stack_host,$(1)), but this is oracle-vm-$(ENV)."; exit 1; }

NGINX_SRC       := $(CURDIR)/nginx
NGINX_SITES_SRC := $(NGINX_SRC)/$(ENV)
NGINX_SITES     := /etc/nginx/sites-available
NGINX_CONF_D    := /etc/nginx/conf.d
NGINX_SNIPPETS  := /etc/nginx/snippets

# Set USE_INFISICAL=1 in prod environment to inject secrets via Infisical CLI.
# Locally, leave unset - docker compose reads from .env as usual.
USE_INFISICAL ?= 0
INFISICAL_ENV ?= prod

ifeq ($(USE_INFISICAL), 1)
  INFISICAL_RUN := infisical run --env=$(INFISICAL_ENV) --
else
  INFISICAL_RUN :=
endif

.PHONY: help init host-setup kai-build nginx-certs nginx-link nginx-apply ufw-apply tailnet-hosts google-calendar-mcp-auth \
        infisical-up infisical-down infisical-ps infisical-logs infisical-restart

# Domains restricted to tailnet-only access (see nginx/snippets/tailnet-only.conf).
# Keep in sync with which vhosts include that snippet.
TAILNET_DOMAINS := grafana.sammaji.com infisical.sammaji.com fitness.sammaji.com \
                   bifrost.sammaji.com listmonk.sammaji.com n8n.sammaji.com

# Domains each host serves; nginx-certs issues one Let's Encrypt cert per domain
# (the vhosts reference /etc/letsencrypt/live/<domain>/). DNS-01 via Cloudflare, so no
# public port 80 is needed - works on a tailnet-only host.
HLAB_CERT_DOMAINS := bifrost.sammaji.com fitness.sammaji.com grafana.sammaji.com infisical.sammaji.com \
                     listmonk.sammaji.com n8n.sammaji.com
PROD_CERT_DOMAINS := api.kai.sammaji.com
CERT_DOMAINS   := $(if $(filter prod,$(ENV)),$(PROD_CERT_DOMAINS),$(HLAB_CERT_DOMAINS))
CERTBOT_EMAIL  ?=
CLOUDFLARE_INI := /etc/letsencrypt/cloudflare.ini


# ── Pattern rules ──
%-up:
	$(call check_host,$*)
	cd $* && $(INFISICAL_RUN) docker compose up -d

%-down:
	cd $* && $(INFISICAL_RUN) docker compose down

%-ps:
	cd $* && $(INFISICAL_RUN) docker compose ps

%-logs:
	cd $* && $(INFISICAL_RUN) docker compose logs -f

%-restart:
	$(call check_host,$*)
	cd $* && $(INFISICAL_RUN) docker compose restart


kai-build:
	$(call check_host,kai)
	cd kai && docker compose build --pull --no-cache


google-calendar-mcp-auth:
	cd google-calendar-mcp && $(INFISICAL_RUN) docker compose run --rm -p 127.0.0.1:3500:3500 calendar-mcp node build/auth-server.js


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
# Makes /etc/nginx/sites-available and sites-enabled exactly $(ENV)'s vhosts: anything
# not in nginx/$(ENV)/ is removed.
nginx-link:
	$(require_vm)
	@echo "Deploying $(ENV)'s vhosts from $(NGINX_SITES_SRC)"
	@sudo mkdir -p $(NGINX_SITES).bak
	@sudo find $(NGINX_SITES).bak -mindepth 1 -delete
	@sudo cp -a $(NGINX_SITES)/. $(NGINX_SITES).bak/
	@echo "Backed up $(NGINX_SITES) -> $(NGINX_SITES).bak"
	@sudo find $(NGINX_SITES) -mindepth 1 -maxdepth 1 ! -name default -delete
	@sudo cp $(NGINX_SITES_SRC)/*.conf $(NGINX_SITES)/
	@echo "Replaced sites-available"
	@sudo mkdir -p $(NGINX_SNIPPETS) && sudo cp $(NGINX_SRC)/snippets/* $(NGINX_SNIPPETS)/
	@echo "Copied snippets"
	@sudo cp $(NGINX_SRC)/conf.d/* $(NGINX_CONF_D)/
	@echo "Copied conf.d"
	@sudo sed -i -E 's/^(\s*)(ssl_protocols|ssl_prefer_server_ciphers)(\s)/\1# \2\3/' /etc/nginx/nginx.conf
	@echo "Commented out ssl_protocols/ssl_prefer_server_ciphers in nginx.conf (ssl-global.conf sets them)"
	@sudo find /etc/nginx/sites-enabled -mindepth 1 -maxdepth 1 -delete
	@for f in $(NGINX_SITES)/*; do \
		sudo ln -s "$$f" /etc/nginx/sites-enabled/$$(basename "$$f"); \
		echo "  Enabled $$(basename $$f)"; \
	done

nginx-certs:
	$(require_vm)
	@echo "Issuing $(ENV)'s certs: $(CERT_DOMAINS)"
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

nginx-apply: nginx-link
	@sudo nginx -t || { echo "nginx -t failed; nginx not restarted. Previous sites in $(NGINX_SITES).bak"; exit 1; }
	@sudo systemctl restart nginx
	@echo "nginx restarted with $(ENV)'s vhosts."


# ── Tailscale / firewall (run on the VPS; requires 'tailscale up' first) ──
ufw-apply:
	@./scripts/setup-ufw.sh


# ── Tailnet-only DNS override (run on client devices, not the VPS) ──
tailnet-hosts:
	@test -n "$(TAILSCALE_VPS_IP)" || { echo "Usage: make tailnet-hosts TAILSCALE_VPS_IP=100.x.x.x"; exit 1; }
	@./scripts/tailnet-hosts.sh $(TAILSCALE_VPS_IP) $(TAILNET_DOMAINS)


# ── Help ──
help:
	@echo "Usage: [USE_INFISICAL=1] [INFISICAL_ENV=prod] [ENV=hlab|prod] make <target>"
	@echo ""
	@echo "This host: $(ENV). Stacks on prod: $(PROD_STACKS); everything else on hlab."
	@echo "nginx-link and nginx-certs act on this host's vhosts and domains."
	@echo ""
	@echo "Secret injection:"
	@echo "  USE_INFISICAL=1   Wrap docker compose with 'infisical run' (set in VPS env)"
	@echo "  INFISICAL_ENV     Infisical environment to use (default: prod)"
	@echo ""
	@echo "Initialization:"
	@echo "  make init             - Setup .env and create symlinks"
	@echo "  make host-setup       - Install Docker, nginx, certbot on a fresh VM"
	@echo ""
	@echo "Nginx:"
	@echo "  make nginx-certs ENV=prod CERTBOT_EMAIL=you@x.com - Issue that VM's certs via Cloudflare DNS-01 (before nginx-apply)"
	@echo "  make nginx-link  ENV=prod - Replace sites-available/enabled with nginx/<ENV>/ (backup in sites-available.bak)"
	@echo "  make nginx-apply ENV=prod - nginx-link, then nginx -t, then restart nginx"
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
	@echo "Kai library (api.kai.sammaji.com):"
	@echo "  make kai-build        - (prod) Rebuild the image from github.com/sammaji/kai (then make kai-up)"
	@echo ""
	@echo "Infisical stack (always uses .env, never Infisical CLI):"
	@echo "  make infisical-up / down / ps / logs / restart"
