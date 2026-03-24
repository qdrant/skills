---
name: qdrant-scaling
description: "How to handle scaling of Qdrant, including horizontal and vertical scaling strategies, sharding, replication, and load balancing. Use when you want to scale your Qdrant deployment to handle increased load or larger datasets."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Scaling

First, determine what you're scaling for: data volume, query throughput (QPS), query latency, tenant count, or IOPS. Note that **throughput** and **latency** optimizations often conflict -— improving one typically requires trade-offs with the other.

More information on trade-offs can be found here:
- Understand the tradeoff [Latency vs throughput](https://qdrant.tech/documentation/guides/optimize/#balancing-latency-and-throughput)
- High speed vs high precision vs low memory: [qdrant performance](https://qdrant.tech/documentation/operations/optimize/)

## Horizontal Scaling

Sharding, resharding, shard planning, vertical vs horizontal decision, and prerequisites for zero-downtime scaling.

More on horizontal scaling can be found in the [Horizontal Scaling](horizontal-scaling/SKILL.md) skill.


## Performance Scaling

Throughput (queries per second, QPS), latency, IOPS limitations, and memory pressure. Different dimensions that pull in different directions.

More on performance scaling can be found in the [Performance Scaling](performance-scaling/SKILL.md) skill.


## Tenant Scaling

Multi-tenant workloads with payload partitioning, per-tenant indexes, and tiered multitenancy.

More on tenant scaling can be found in the [Tenant Scaling](tenant-scaling/SKILL.md) skill.
