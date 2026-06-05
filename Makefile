SHELL := /bin/bash

NGINX_SRC      := $(CURDIR)/nginx
NGINX_SITES    := /etc/nginx/sites-available
NGINX_CONF_D   := /etc/nginx/conf.d
NGINX_SNIPPETS := /etc/nginx/snippets

# Set USE_INFISICAL=1 in prod environment to inject secrets via Infisical CLI.
# Locally, leave unset - docker-compose reads from .env as usual.
USE_INFISICAL ?= 0
INFISICAL_ENV ?= prod

ifeq ($(USE_INFISICAL), 1)
  INFISICAL_RUN := infisical run --env=$(INFISICAL_ENV) --
else
  INFISICAL_RUN :=
endif

.PHONY: help init nginx-link nginx-apply \
        infisical-up infisical-down infisical-ps infisical-logs infisical-restart


# ── Pattern rules ──
%-up:
	cd $* && $(INFISICAL_RUN) docker-compose up -d

%-down:
	cd $* && docker-compose down

%-ps:
	cd $* && docker-compose ps

%-logs:
	cd $* && docker-compose logs -f

%-restart:
	cd $* && $(INFISICAL_RUN) docker-compose restart


# ── Infisical (always uses .env — it IS the secret store) ──
infisical-up:
	cd infisical && docker-compose up -d

infisical-down:
	cd infisical && docker-compose down

infisical-ps:
	cd infisical && docker-compose ps

infisical-logs:
	cd infisical && docker-compose logs -f

infisical-restart:
	cd infisical && docker-compose restart


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
	@echo "Relinking sites-enabled..."
	@sudo rm -f /etc/nginx/sites-enabled/*
	@for f in $(NGINX_SITES)/*; do \
		sudo ln -s "$$f" /etc/nginx/sites-enabled/$$(basename "$$f"); \
		echo "  Linked $$(basename $$f)"; \
	done
	@echo "Done. Run 'make nginx-apply' to test and reload."

nginx-apply:
	@sudo nginx -t || { echo "nginx -t failed, aborting."; exit 1; }
	@printf "nginx -t passed. Restart nginx? [y/N] "; \
	read ans; \
	[[ "$$ans" == [yY] ]] || { echo "Aborted."; exit 0; }; \
	sudo systemctl restart nginx; \
	echo "nginx restarted."


# ── Help ──
help:
	@echo "Usage: [USE_INFISICAL=1] [INFISICAL_ENV=prod] make <target>"
	@echo ""
	@echo "Secret injection:"
	@echo "  USE_INFISICAL=1   Wrap docker-compose with 'infisical run' (set in VPS env)"
	@echo "  INFISICAL_ENV     Infisical environment to use (default: prod)"
	@echo ""
	@echo "Initialization:"
	@echo "  make init             - Setup .env and create symlinks"
	@echo ""
	@echo "Nginx:"
	@echo "  make nginx-link       - Backup /etc/nginx/sites-available and deploy nginx/ configs"
	@echo "  make nginx-apply      - Test nginx config; if ok, restart nginx"
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
