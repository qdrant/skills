---
name: qdrant-performance-optimization
description: "Navigation hub linking sub-skills for proactive Qdrant tuning: search speed, indexing performance, and memory usage optimization. Use when planning configuration or capacity changes to improve speed and efficiency. For diagnosing an active production slowdown or analyzing live metrics, use qdrant-monitoring instead."
allowed-tools:
  - Read
  - Grep
  - Glob
---


# Qdrant Performance Optimization

Route first, then answer. Match the user's symptom in the table, `Read` that
file, and answer from it. Do not answer from this page alone: it contains
routing only, not the guidance. If two rows match, read both.

| The user says | Read |
|---|---|
| Queries too slow or throughput too low, tune for latency vs QPS | `search-speed-optimization/SKILL.md` |
| Uploads/indexing slow, HNSW build takes too long, optimizer stuck | `indexing-performance-optimization/SKILL.md` |
| RAM/memory too high, node crashed OOM, want to move data to disk | `memory-usage-optimization/SKILL.md` |

Latency and throughput pull opposite ways on segment count. For latency,
increase segments toward the CPU core count (`default_segment_number: 16`).
For throughput, use fewer and larger segments (`default_segment_number: 2`).
Applying the wrong direction makes the reported problem worse.