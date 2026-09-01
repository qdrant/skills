---
name: qdrant-performance-optimization
description: "Navigation hub linking sub-skills for proactive Qdrant tuning: search speed, indexing performance, and memory usage optimization. Use when planning configuration or capacity changes to improve speed and efficiency. For diagnosing an active production slowdown or analyzing live metrics, use qdrant-monitoring instead."
allowed-tools:
  - Read
  - Grep
  - Glob
---


# Qdrant Performance Optimization

Route first, then answer. Match the user's symptom in the table, `Read` that file, and answer from it.
Do not answer from this page alone: it contains routing only, not the guidance. If two rows match, read both.

| The user says | Read |
|---|---|
| Filtered queries much slower than unfiltered | `search-speed-optimization/SKILL.md` |
| Low QPS, cannot handle the query load | `search-speed-optimization/SKILL.md` |
| Individual queries take too long to return | `search-speed-optimization/SKILL.md` |
| Index build or HNSW build takes too long, vector upload is slow | `indexing-performance-optimization/SKILL.md` |
| Collection stays yellow, optimizer stuck or runs for a long time | `indexing-performance-optimization/SKILL.md` |
| Bulk upsert of vectors is slow | `indexing-performance-optimization/SKILL.md` |
| RAM usage too high, out-of-memory crashes | `memory-usage-optimization/SKILL.md` |
| Want to fit a larger dataset on the same hardware | `memory-usage-optimization/SKILL.md` |
| Reducing cost by moving data to disk | `memory-usage-optimization/SKILL.md` |

Latency and throughput pull opposite ways on segment count.
For latency, increase segments toward the CPU core count (`default_segment_number: 16`).
For throughput, use fewer and larger segments (`default_segment_number: 2`).
Applying the wrong direction makes the reported problem worse.
