---
name: qdrant-monitoring-setup
description: "Guides Qdrant monitoring setup including Prometheus scraping, Datadog integration, health probes, Hybrid Cloud metrics, alerting, and log centralization. Use when someone asks 'how to set up monitoring', 'Prometheus config', 'send metrics to Datadog', 'Grafana dashboard', 'health check endpoints', 'how to scrape Hybrid Cloud', 'what alerts to set', 'how to centralize logs', or 'audit logging'."
---

# How to Set Up Qdrant Monitoring

Get Prometheus scraping working first, then health probes, then alerting. Do not skip monitoring setup before going to production.


## Prometheus Metrics

Use when: setting up metric collection for the first time or adding a new deployment.

- Node metrics at `/metrics` endpoint [Monitoring docs](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/)
- Cluster metrics at `/sys_metrics` (Qdrant Cloud only)
- To add a prefix to metric names, see [Metrics configuration](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/?s=metrics-configuration)
- Example self-hosted setup with Prometheus + Grafana [prometheus-monitoring repo](https://github.com/qdrant/prometheus-monitoring)
- Datadog integration: collect metrics via the OpenMetrics `/metrics` endpoint [Datadog integration](https://skills.qdrant.tech/md/documentation/observability/datadog/)


## Hybrid Cloud Scraping

Use when: running Qdrant Hybrid Cloud and need cluster-level visibility.

Do not just scrape Qdrant nodes. In Hybrid Cloud, you manage the Kubernetes data plane. You must also scrape the cluster-exporter and operator pods for full cluster visibility and operator state.

- Hybrid Cloud Prometheus setup tutorial [Hybrid Cloud Prometheus](https://skills.qdrant.tech/md/documentation/ops-monitoring/hybrid-cloud-prometheus/)
- Official Grafana dashboards [Grafana dashboard repo](https://github.com/qdrant/qdrant-cloud-grafana-dashboard)


## Liveness and Readiness Probes

Use when: configuring Kubernetes health checks.

- Use `/healthz`, `/livez`, `/readyz` for basic status, liveness, and readiness [Kubernetes health endpoints](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/?s=kubernetes-health-endpoints)


## Alerting

Use when: setting up alerts for production or Hybrid Cloud deployments.

- Qdrant Cloud provides pre-configured email alerts for 11 cluster issues. Use scraped metrics when you need custom alerts or routing to other targets. See [Cloud cluster monitoring](https://skills.qdrant.tech/md/documentation/cloud/cluster-monitoring/)
- Use AlertmanagerConfig to route alerts to Slack, PagerDuty, or other targets based on labels
- At minimum, alert on: optimizer errors, node not ready, replication factor below target, disk usage >80%


## Log Centralization and Audit Logging

Use when: enterprise compliance requires centralized logs or audit trails.

- Enable JSON log format for structured analysis: set `logger.format` to `json` in config [Configuration](https://skills.qdrant.tech/md/documentation/ops-configuration/configuration/)
- Use FluentD/OpenSearch for log aggregation
- Audit logging (v1.17+) is off by default; turn it on with `audit.enabled: true` [Audit logging](https://skills.qdrant.tech/md/documentation/security/?s=audit-logging). Audit logs write to local filesystem (`/qdrant/storage/audit/`) by default. On v1.20 or newer, set `audit.output` to `stdout`, `stderr`, `file_and_stdout`, or `file_and_stderr` (env var `QDRANT__AUDIT__OUTPUT`) so a DaemonSet can collect them with no sidecar or Persistent Volume. Each line carries `"kind": "audit"` to tell it from regular logs, and the `/audit/logs` API returns nothing on a node that writes only to a stream. On v1.19 or older, mount a Persistent Volume and deploy a sidecar container to tail the files to stdout. [Audit logging](https://skills.qdrant.tech/md/documentation/security/?s=audit-log-output)


## What NOT to Do

- Scrape `/sys_metrics` on self-hosted (only available on Qdrant Cloud)
- Scrape only Qdrant nodes in Hybrid Cloud (miss cluster-exporter and operator metrics)
- Skip monitoring setup before going to production (you will regret it)
- Alert on page cache memory usage (it's supposed to fill available RAM, normal OS behavior)
