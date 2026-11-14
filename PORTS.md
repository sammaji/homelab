# Ports

Host port registry for **`oracle-vm-hlab`**, the only host this repo's stacks
run on.

Host ports start at **5000**. Each stack gets a block and keeps a buffer for
future containers: at least 5-10 ports, 20 for large stacks. Containers are
reached through nginx or directly over the tailnet. Nothing here is opened
publicly.

## Allocations

| Block | Stack |
|-------|-------|
| 5000-5019 | `monitoring` |
| 5020-5024 | `infisical` |
| 5025-5039 | `bifrost` |
| 5040-5054 | `n8n` |
| 5055-5069 | `listmonk` |
| 5070-5089 | `media` |
| 5090+ | free (next stack starts here) |

## Ports

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
| 5070 | 8096 | jellyfin | Jellyfin UI |
| 5071 | 9696 | prowlarr | Prowlarr UI |
| 5072 | 7878 | radarr | Radarr UI |
| 5073 | 8989 | sonarr | Sonarr UI |
| 5074 | 8080 | qbittorrent | qBittorrent Web UI |
| 5075 | 5075 | qbittorrent | qBittorrent Peer (TCP+UDP) |
