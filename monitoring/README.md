# Monitoring stack

OpenTelemetry-based observability stack: metrics, traces, and logs collected via the OTel Collector, stored in Prometheus (metrics) and Tempo (traces), visualized in Grafana.

See `PORTS.md` at repository root for full port reference.

| Service    | URL                    |
|------------|------------------------|
| Grafana    | http://localhost:5000  |
| Prometheus | http://localhost:5001  |
| Tempo      | http://localhost:5002  |
