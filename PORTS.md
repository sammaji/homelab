# Ports

All ports are ordered by `Host Port` for public ports.

Always keep a buffer of at least 5-10 ports open between services. 20 if your service is large. For example, `monitoring` stack takes ports 5600-5619 (20 ports). Infisical takes 5620-5624 (5 ports), etc.

| Host Port | Container Port | Service | Description |
|-----------|---------------|---------|-------------|
| 5200 | 3000 | watchthatsite-proxy | Watchthatsite Proxy |
| 5201 | 8080 | watchthatsite-bifrost | Watchthatsite Bifrost |
| 5600 | 3000 | grafana | Grafana UI |
| 5600 | 3000 | grafana | Grafana UI |
| 5601 | 9090 | prometheus | Prometheus UI |
| 5602 | 3200 | tempo | Tempo HTTP API |
| 5603 | 4317 | otel-collector | OTLP gRPC receiver |
| 5604 | 4318 | otel-collector | OTLP HTTP receiver |
| 5605 | 8888 | otel-collector | OTLP Internal metrics |
| 5606 | 9464 | otel-collector | Prometheus exporter |
| 5607 | 13133 | otel-collector | OTLP Health check |
| 5620 | 8080 | infisical | Infisical UI & API |
| 5625 | 8080 | bifrost | Bifrost UI & API |
| 5640 | 5678 | n8n | n8n UI & API (webhooks) |

