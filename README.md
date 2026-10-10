# homelab

Self-hosted infrastructure for a single VPS: Docker Compose stacks, nginx reverse proxy, and Terraform for DNS/VM provisioning. Secrets are managed with [Infisical](https://infisical.com) and injected at runtime via the Infisical CLI in production.

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
├── listmonk/               # Listmonk newsletter/mailing list manager (+ Postgres)
├── monitoring/             # OTel Collector + Prometheus + Tempo + Grafana
├── nginx/                  # Reverse proxy configs (sites, snippets, conf.d)
└── terraform/
    ├── cloudflare-dns/     # Cloudflare DNS records
    └── oracle-vm/          # Oracle VM provisioning
```

## Stacks

| Stack | Description | Ports (host) |
|-------|-------------|--------------|
| `infisical` | Self-hosted secret manager (UI + API, Postgres, Redis). Tailnet-only via `infisical.sammaji.com` | 5020 |
| `bifrost` | LLM gateway (UI + API, Postgres). `bifrost.sammaji.com`: `/v1`, `/openai`, `/anthropic` public, rest tailnet-only | 5025 |
| `media` | Jellyfin (public via `jellyfin.sammaji.com`) + Prowlarr/Radarr/Sonarr + qBittorrent. Admin UIs bind to loopback only — reach via Tailscale/SSH tunnel | 5630–5635 |
| `listmonk` | Newsletter/mailing list manager. `listmonk.sammaji.com`: subscriber-facing pages (`/subscription`, `/link`, `/campaign`) and the SES bounce webhook public, admin UI tailnet-only + Postgres. SMTP (AWS SES) is configured post-boot via the admin UI - see [`listmonk/ses-smtp-setup.md`](listmonk/ses-smtp-setup.md) | 5055 |
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
make nginx-link    # Back up /etc/nginx/sites-available, deploy nginx/ configs, relink sites-enabled
make nginx-apply   # nginx -t, then restart nginx if it passes
```

`make help` lists all targets.

## Networking

The VPS runs [Tailscale](https://tailscale.com) alongside `ufw` and nginx to split
every service into one of three access tiers:

- **Public** — reachable from the internet on 80/443, no restriction (e.g.
  `nocodb.sammaji.com`, `api.budget-bee.app`, `proxy.watchthat.site`).
- **Tailnet-only** — the nginx vhost's `location /` includes
  [`nginx/snippets/tailnet-only.conf`](nginx/snippets/tailnet-only.conf), which 403s
  any request not sourced from the tailnet's `100.64.0.0/10` range or localhost (e.g.
  `grafana.sammaji.com`, `infisical.sammaji.com`).
- **Partial** — specific path prefixes stay public (webhooks, inference endpoints,
  subscriber-facing pages), everything else is tailnet-only. See
  `bifrost.sammaji.com.conf`, `n8n.sammaji.com.conf`, `listmonk.sammaji.com.conf`.

Every raw host port in [`PORTS.md`](PORTS.md) is bound the same way regardless of
tier — `ufw`'s default-deny keeps it off the public internet no matter what; only
22 (SSH), 80, 443, and Tailscale's own port (`41641/udp`) are opened publicly, plus a
blanket `allow in on tailscale0` that trusts anything arriving over the tailnet. SSH
is unaffected by any of this — it stays public and key-based.

Setup, on the VPS, after `tailscale up`:

```bash
make ufw-apply
```

A tailnet-only domain's public DNS still resolves to the VPS's public IP (which nginx
will 403), so map it to the VPS's Tailscale IP locally on each client device instead:

```bash
make tailnet-hosts TAILSCALE_VPS_IP=100.x.x.x
```

New service added? If it should be public, no extra step is needed. If it should be
tailnet-only or partial, add the `tailnet-only.conf` include to its vhost (see the
existing tailnet-only/partial vhosts for the pattern) and add its domain to
`TAILNET_DOMAINS` in the `Makefile`.

## Terraform

Both modules read provider credentials from environment variables.

```bash
cd terraform/cloudflare-dns        # or terraform/gcp-vm, terraform/aws-ses
cp terraform.tfvars.example terraform.tfvars   # fill in
terraform init && terraform plan
```

- **cloudflare-dns** — manages DNS records for `sammaji.com`, `budget-bee.app`, `watchthat.site`. Needs `CLOUDFLARE_API_TOKEN` (`Zone:DNS:Edit` + `Zone:Zone:Read`).
- **gcp-vm** — provisions the GCP VM. Needs `GOOGLE_CREDENTIALS` (service-account key path or JSON). See [`terraform/gcp-vm/SETUP.md`](terraform/gcp-vm/SETUP.md).
- **aws-ses** — provisions AWS SES for `updates.budget-bee.app` (domain verification, DKIM, MAIL FROM, SPF/DMARC, writing the resulting DNS records into the `budget-bee.app` Cloudflare zone directly), an IAM user scoped to that identity for listmonk's SMTP credentials, and a $10/mo cost cap with an automatic send cutoff. Needs `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (SES, IAM, Budgets/Cost Explorer) and `CLOUDFLARE_API_TOKEN`. See [`terraform/aws-ses/README.md`](terraform/aws-ses/README.md).

State and `*.tfvars` are gitignored.
