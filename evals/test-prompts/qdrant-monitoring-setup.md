---
id: qdrant-monitoring-setup
skill_url: https://skills.qdrant.tech/qdrant-monitoring/setup/SKILL.md
rubric:
  must:
    - Sets up Prometheus scraping of the node /metrics endpoint with Grafana dashboards
    - For Hybrid Cloud, also scrapes the cluster-exporter and operator pods, not just the Qdrant nodes
    - Configures Kubernetes liveness/readiness probes via /healthz, /livez, /readyz
    - Defines baseline alerts (optimizer errors, node not ready, replication below target, disk >80%)
  bonus:
    - Mentions Hybrid Cloud's ~11 preconfigured alerts and/or official Grafana dashboards
    - Covers log centralization (JSON log format; audit logs need a PV + sidecar to reach stdout)
  avoid:
    - Tells the user to scrape /sys_metrics (Cloud-only, unavailable on this self-managed data plane)
    - Recommends alerting on page-cache memory usage as if it were a fault
---
We're about to put a 3-node cluster into production on our own Kubernetes via Hybrid Cloud. Before launch I want real observability — scraping, dashboards, health checks, and a sensible alert set. What should we wire up, and what are the gotchas for a Hybrid Cloud setup specifically?
