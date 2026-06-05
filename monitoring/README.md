# Monitoring stack

OpenTelemetry-based observability stack: metrics, traces, and logs collected via the OTel Collector, stored in Prometheus (metrics) and Tempo (traces), visualized in Grafana.

See `PORTS.md` at repository root for full port reference.

| Service    | URL                    |
|------------|------------------------|
| Grafana    | http://localhost:5600  |
| Prometheus | http://localhost:5601  |
| Tempo      | http://localhost:5602  |
