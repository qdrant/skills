---
name: qdrant-monitoring
description: "Guides Qdrant monitoring and observability setup. Use when someone asks 'how to monitor Qdrant', 'what metrics to track', 'is Qdrant healthy', 'optimizer stuck', 'why is memory growing', 'requests are slow', or needs to set up Prometheus, Grafana, or health checks. Also use when debugging production issues that require metric analysis."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Monitoring

## Symptom to Sub-skill Map

| Symptom | Sub-skill |
|---|---|
| Want to set up Prometheus, Grafana, or health checks | [Monitoring Setup](setup/SKILL.md) |
| Need to know which metrics to track | [Monitoring Setup](setup/SKILL.md) |
| Setting up alerting or log centralization | [Monitoring Setup](setup/SKILL.md) |
| Optimizer stuck or running forever | [Debugging with Metrics](debugging/SKILL.md) |
| Memory keeps growing in production | [Debugging with Metrics](debugging/SKILL.md) |
| Requests are slow and I need to find out why | [Debugging with Metrics](debugging/SKILL.md) |
| Diagnosing an active production issue with metrics | [Debugging with Metrics](debugging/SKILL.md) |

Qdrant monitoring allows tracking performance and health of your deployment, and identifying issues before they become outages. First determine whether you need to set up monitoring or diagnose an active issue.

- Understand available metrics [Monitoring docs](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/)


## Monitoring Setup

Prometheus scraping, health probes, Hybrid Cloud specifics, alerting, and log centralization. [Monitoring Setup](setup/SKILL.md)


## Debugging with Metrics

Optimizer stuck, memory growth, slow requests. Using metrics to diagnose active production issues. [Debugging with Metrics](debugging/SKILL.md)
