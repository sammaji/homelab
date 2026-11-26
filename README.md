# homelab

Self-hosted infrastructure for two VPSs: Docker Compose stacks, nginx reverse proxy, and Terraform for DNS/VM provisioning. Secrets are managed with [Infisical](https://infisical.com) and injected at runtime via the Infisical CLI in production.

## Layout

```
.
├── Makefile                # Entry point for all stack + nginx operations
├── PORTS.md                # Host port allocation registry
├── .env.example            # Template for all stack secrets
├── scripts/
│   └── create_symlinks.sh  # Bootstraps .env and per-stack symlinks
├── infisical/              # Secret manager (Infisical + Postgres + Redis)
├── bifrost/                # Bifrost LLM gateway (+ Postgres)
├── kai/                    # Kai's library service (api.kai.sammaji.com), on prod
├── listmonk/               # Listmonk newsletter/mailing list manager (+ Postgres)
├── sparkyfitness/          # SparkyFitness fitness/nutrition tracker (+ Postgres)
├── monitoring/             # OTel Collector + Prometheus + Tempo + Grafana
├── nginx/                  # Reverse proxy: hlab/ and prod/ vhosts, shared snippets/ and conf.d/
└── terraform/
    ├── cloudflare-dns/     # Cloudflare DNS records
    └── oracle-vm/          # Oracle VM provisioning
```

## Hosts

Two Always Free Oracle VMs (`terraform/oracle-vm`), same specs (1 OCPU, 6 GB, 100 GB):

| Host | Role | Public surface |
|------|------|----------------|
| `oracle-vm-hlab` | My self-hosted services. Tailnet-only domains point at its Tailscale IP; `bifrost`, `listmonk` and `n8n` point at its public IP for their public paths | 80/443 (nginx; only the public paths of those three vhosts answer) |
| `oracle-vm-prod` | Public side-project traffic. DNS points at its public IP | 80/443 (nginx) |

Make targets take `ENV=hlab|prod` (on a VM it defaults to that VM, from the hostname):

- `PROD_STACKS` lists the stacks that run on prod (`kai`); every other stack runs on
  hlab. `make <stack>-up` refuses to start a stack on the wrong VM.
- `make nginx-apply ENV=prod` deploys `nginx/prod/` (or `nginx/hlab/`), tests the
  config and restarts nginx. Deploying *replaces* `/etc/nginx/sites-available` and
  `sites-enabled` (Ubuntu's `default` stays, the previous state goes to
  `sites-available.bak`), so a vhost deleted from the repo disappears from the VM.
- `make nginx-certs ENV=prod` issues `PROD_CERT_DOMAINS` (or `HLAB_CERT_DOMAINS`).

### Setting up prod

On `oracle-vm-prod`, after Tailscale and ufw (see
[`terraform/oracle-vm/vm-tailscale-setup.md`](terraform/oracle-vm/vm-tailscale-setup.md)):

```bash
git clone https://github.com/sammaji/homelab ~/sammaji/homelab && cd ~/sammaji/homelab
./scripts/setup-host.sh          # Docker, nginx, certbot, make; then log out and back in
make init
# Cloudflare token (Zone:DNS:Edit on sammaji.com only) for DNS-01 certs:
sudo mkdir -p /etc/letsencrypt && echo 'dns_cloudflare_api_token = <token>' | sudo tee /etc/letsencrypt/cloudflare.ini >/dev/null && sudo chmod 600 /etc/letsencrypt/cloudflare.ini
make nginx-certs ENV=prod CERTBOT_EMAIL=you@example.com
make kai-up                      # first run builds the image
make nginx-apply ENV=prod
```

To move a stack to prod: add it to `PROD_STACKS`, move its vhost to
`nginx/prod/`, its domain to `PROD_CERT_DOMAINS`, and its DNS
record to one that uses `local.prod_vm_ip` in `terraform/cloudflare-dns`.

## Stacks

| Stack | Description | Ports (host) |
|-------|-------------|--------------|
| `infisical` | Self-hosted secret manager (UI + API, Postgres, Redis). Tailnet-only via `infisical.sammaji.com` | 5020 |
| `bifrost` | LLM gateway (UI + API, Postgres). `bifrost.sammaji.com`: `/v1`, `/openai`, `/anthropic` public, rest tailnet-only | 5025 |
| `media` | Jellyfin (public via `jellyfin.sammaji.com`) + Prowlarr/Radarr/Sonarr + qBittorrent. Admin UIs bind to loopback only — reach via Tailscale/SSH tunnel | 5630–5635 |
| `listmonk` | Newsletter/mailing list manager. `listmonk.sammaji.com`: subscriber-facing pages (`/subscription`, `/link`, `/campaign`) and the SES bounce webhook public, admin UI tailnet-only + Postgres. SMTP (AWS SES) is configured post-boot via the admin UI - see [`listmonk/ses-smtp-setup.md`](listmonk/ses-smtp-setup.md) | 5055 |
| `sparkyfitness` | Self-hosted fitness and nutrition tracker ([SparkyFitness](https://codewithcj.github.io/SparkyFitness/)): frontend, server, Postgres. Tailnet-only via `fitness.sammaji.com`. Register your account, then set `SPARKY_FITNESS_DISABLE_SIGNUP=true` and `make sparkyfitness-restart` | 5070 |
| `kai` | **prod.** Kai's library: the MCP catalog, icons and model data Kai instances read. Built from `github.com/sammaji/kai`; public, read-only via `api.kai.sammaji.com`. `make kai-build` to update | 5000 (prod) |
| `monitoring` | OpenTelemetry observability: metrics → Prometheus, traces → Tempo, dashboards → Grafana (tailnet-only via `grafana.sammaji.com`) | 5000–5007 |

See [`PORTS.md`](PORTS.md) for the full host port registry. Rule: keep a 5–10 port buffer between services (20 for large ones). See [Networking](#networking) for which services are public vs. tailnet-only.

## Secret management

`.env` at the repo root is the single source of secrets. `scripts/create_symlinks.sh` symlinks each stack's `.env` to it (skips `nginx`, `terraform`), so there is one file to edit.

- **Local**: docker compose reads `.env` directly.
- **Production**: set `USE_INFISICAL=1` so the Makefile wraps every `docker compose` call with `infisical run --env=prod --`, injecting secrets from Infisical instead of `.env`.

The `infisical` stack itself always reads `.env` directly — it *is* the secret store, so it can't depend on itself.

## Usage

### First-time setup

```bash
make init          # Copies .env.example -> .env and creates per-stack symlinks
$EDITOR .env       # Fill in secrets
```

### Manage a stack

Pattern rules work for any stack folder (`infisical`, `bifrost`, `monitoring`):

```bash
make <stack>-up        # docker compose up -d
make <stack>-down      # docker compose down
make <stack>-ps        # list containers
make <stack>-logs      # stream logs
make <stack>-restart   # restart
```

In production, prefix with Infisical injection:

```bash
USE_INFISICAL=1 make bifrost-up
USE_INFISICAL=1 INFISICAL_ENV=prod make monitoring-up
```

### Nginx

```bash
make nginx-apply ENV=hlab   # replace sites-available/enabled with nginx/hlab/, nginx -t, restart
make nginx-apply ENV=prod   # same with nginx/prod/ (only api.kai.sammaji.com)
make nginx-link ENV=prod    # just deploy the files, no test or restart
```

`make help` lists all targets.

## Networking

The VPS runs [Tailscale](https://tailscale.com) alongside `ufw` and nginx to split
every service into one of three access tiers:

- **Public** — reachable from the internet on 80/443, no restriction (e.g.
  `api.kai.sammaji.com` on prod).
- **Tailnet-only** — the nginx vhost's `location /` includes
  [`nginx/snippets/tailnet-only.conf`](nginx/snippets/tailnet-only.conf), which 403s
  any request not sourced from the tailnet's `100.64.0.0/10` range or localhost (e.g.
  `grafana.sammaji.com`, `infisical.sammaji.com`).
- **Partial** — specific path prefixes stay public (webhooks, inference endpoints,
  subscriber-facing pages), everything else is tailnet-only. See
  `bifrost.sammaji.com.conf`, `n8n.sammaji.com.conf`, `listmonk.sammaji.com.conf`, `fitness.sammaji.com.conf`.

Every raw host port in [`PORTS.md`](PORTS.md) is bound the same way regardless of
tier — `ufw`'s default-deny keeps it off the public internet no matter what; only
22 (SSH), 80, 443, and Tailscale's own port (`41641/udp`) are opened publicly, plus a
blanket `allow in on tailscale0` that trusts anything arriving over the tailnet. SSH
is unaffected by any of this — it stays public and key-based.

Setup, on the VPS, after `tailscale up`:

```bash
make ufw-apply
```

A partial domain's public DNS resolves to hlab's public IP (where nginx 403s everything
but the public paths), so map it to hlab's Tailscale IP locally on each client device to
reach its admin side. Tailnet-only domains already resolve to the Tailscale IP; they're
in the list too in case that changes:

```bash
make tailnet-hosts TAILSCALE_VPS_IP=100.x.x.x
```

New service added? If it should be public, no extra step is needed. If it should be
tailnet-only or partial, add the `tailnet-only.conf` include to its vhost (see the
existing tailnet-only/partial vhosts for the pattern) and add its domain to
`TAILNET_DOMAINS` in the `Makefile`. On hlab, point a partial domain's DNS record at
`local.hlab_vm_ip` and a tailnet-only one at `var.vps_ip` (`terraform/cloudflare-dns`).

`nginx/hlab/00-default.conf` refuses the TLS handshake for any SNI that matches no
vhost, so scans of hlab's public IP don't land on the first vhost.

## Terraform

Both modules read provider credentials from environment variables.

```bash
cd terraform/cloudflare-dns        # or terraform/gcp-vm, terraform/aws-ses
cp terraform.tfvars.example terraform.tfvars   # fill in
terraform init && terraform plan
```

- **cloudflare-dns** — manages DNS records for `sammaji.com` and `watchthat.site`. hlab records use `vps_ip` (its Tailscale IP); prod records read prod's public IP from `terraform/oracle-vm`'s state, so apply that module first. Needs `CLOUDFLARE_API_TOKEN` (`Zone:DNS:Edit` + `Zone:Zone:Read`).
- **gcp-vm** — provisions the GCP VM. Needs `GOOGLE_CREDENTIALS` (service-account key path or JSON). See [`terraform/gcp-vm/SETUP.md`](terraform/gcp-vm/SETUP.md).
- **aws-ses** — provisions AWS SES for `updates.budget-bee.app` (domain verification, DKIM, MAIL FROM, SPF/DMARC, writing the resulting DNS records into the `budget-bee.app` Cloudflare zone directly), an IAM user scoped to that identity for listmonk's SMTP credentials, and a $10/mo cost cap with an automatic send cutoff. Needs `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (SES, IAM, Budgets/Cost Explorer) and `CLOUDFLARE_API_TOKEN`. See [`terraform/aws-ses/README.md`](terraform/aws-ses/README.md).

State and `*.tfvars` are gitignored.
