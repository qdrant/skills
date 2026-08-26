---
name: qdrant-monitoring
description: "Guides Qdrant monitoring and observability setup. Use when someone asks 'how to monitor Qdrant', 'what metrics to track', 'is Qdrant healthy', 'optimizer stuck', 'why is memory growing', 'requests are slow', 'set up alerts', 'cluster health check', or needs to set up Prometheus, Grafana, health checks, or log centralization. Also use when debugging production issues that require metric analysis."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Monitoring

Route first, then answer. Match the user's symptom in the table, `Read` that
file, and answer from it. Do not answer from this page alone: it contains
routing only, not the guidance. If two rows match, read both.

| The user says | Read |
|---|---|
| Set up monitoring: Prometheus scraping, health probes, Hybrid Cloud metrics, alerting, log centralization | `setup/SKILL.md` |
| Diagnose an active issue: optimizer stuck, memory growing, requests slow, is Qdrant healthy | `debugging/SKILL.md` |

Qdrant monitoring tracks performance and health, and catches issues before they
become outages. See the metric reference before tuning anything:
[Monitoring docs](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/)
