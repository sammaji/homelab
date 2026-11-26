# Ports

Host port registry for **`oracle-vm-hlab`** (self-hosted services, tailnet-only) and
**`oracle-vm-prod`** (public traffic). Each VM has its own allocations, both starting
at **5000**, so the same port can mean different things on each VM. `PROD_STACKS` in
the `Makefile` says which stacks run on prod; moving a stack to the other VM means
giving it a block in that VM's table.

Each stack gets a block and keeps a buffer for future containers: at least 5-10
ports, 20 for large stacks. Containers bind to loopback and are reached through
nginx or over the tailnet. Nothing here is opened publicly.

## Allocations

### oracle-vm-hlab

| Block | Stack |
|-------|-------|
| 5000-5019 | `monitoring` |
| 5020-5024 | `infisical` |
| 5025-5039 | `bifrost` |
| 5040-5054 | `n8n` |
| 5055-5069 | `listmonk` |
| 5070-5079 | `sparkyfitness` |
| 5080+ | free (next stack starts here) |

### oracle-vm-prod

| Block | Stack |
|-------|-------|
| 5000-5004 | `kai` |
| 5005+ | free (next stack starts here) |

## Ports

### oracle-vm-hlab

| Host Port | Container Port | Service | Description |
|-----------|---------------|---------|-------------|
| 5000 | 3000 | grafana | Grafana UI |
| 5001 | 9090 | prometheus | Prometheus UI |
| 5002 | 3200 | tempo | Tempo HTTP API |
| 5003 | 4317 | otel-collector | OTLP gRPC receiver |
| 5004 | 4318 | otel-collector | OTLP HTTP receiver |
| 5005 | 8888 | otel-collector | OTel Collector internal metrics |
| 5006 | 9464 | otel-collector | Prometheus exporter |
| 5007 | 13133 | otel-collector | Health check |
| 5008 | 9095 | tempo | Tempo gRPC |
| 5009 | 3100 | loki | Loki HTTP API |
| 5020 | 8080 | infisical | Infisical UI & API |
| 5025 | 8080 | bifrost | Bifrost UI & API |
| 5040 | 5678 | n8n | n8n UI & API (webhooks) |
| 5055 | 9000 | listmonk | Listmonk UI & API |
| 5070 | 80 | sparkyfitness-frontend | SparkyFitness UI (its nginx proxies /api to the server), served at fitness.sammaji.com |

### oracle-vm-prod

| Host Port | Container Port | Service | Description |
|-----------|---------------|---------|-------------|
| 5000 | 4100 | kai-library | Kai library (MCP catalog, icons, models), served at api.kai.sammaji.com |
