---
name: qdrant-scaling
description: "Guides Qdrant scaling decisions. Use when someone asks 'how many nodes do I need', 'data doesn't fit on one node', 'need more throughput', 'cluster is slow', 'too many tenants', 'vertical or horizontal', 'how to shard', or 'need to add capacity'."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Scaling

First determine what you're scaling for: data volume, query throughput (QPS), query latency, tenant count, or IOPS. Each pulls toward different strategies. Scaling for throughput and latency are opposite tuning directions.

- Understand the tradeoff [Latency vs throughput](https://qdrant.tech/documentation/guides/optimize/#balancing-latency-and-throughput)
- High speed vs high precision vs low memory: [qdrant performance](https://qdrant.tech/documentation/operations/optimize/)

## Horizontal Scaling

Sharding, resharding, shard planning, vertical vs horizontal decision, and prerequisites for zero-downtime scaling. [Horizontal Scaling](horizontal-scaling/SKILL.md)


## Performance Scaling

Throughput (queries per second, QPS), latency, IOPS limitations, and memory pressure. Different dimensions that pull in different directions. [Performance Scaling](performance-scaling/SKILL.md)


## Tenant Scaling

Multi-tenant workloads with payload partitioning, per-tenant indexes, and tiered multitenancy. [Tenant Scaling](tenant-scaling/SKILL.md)
