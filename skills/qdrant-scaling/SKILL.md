---
name: qdrant-scaling
description: "Guides Qdrant scaling decisions. Use when someone asks 'how many nodes do I need', 'data doesn't fit on one node', 'need more throughput or QPS', 'CPU is pegged / can't keep up with the request rate', 'one query is slow / p99 or tail latency too high', 'cluster is slow', 'too many tenants', 'vertical or horizontal', 'how to shard', 'need to add capacity', 'large limit / pagination / scroll is slow', or 'only recent data matters / expiring old vectors / retention window'."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Scaling

Route first, then answer. Match the user's symptom in the table, `Read` that
file, and answer from it. Do not answer from this page alone: it contains
routing only, not the guidance. If two rows match, read both.

| The user says | Read |
|---|---|
| Data outgrew one node, need more storage, sharding | `scaling-data-volume/SKILL.md` |
| Can't hold the request rate, CPU pegged, need more QPS or throughput | `scaling-qps/SKILL.md` |
| One query is slow, p99 or tail latency too high, traffic is fine | `minimize-latency/SKILL.md` |
| Large `limit`, top-1000 queries, pagination, scroll across shards | `scaling-query-volume/SKILL.md` |
| Many tenants or customers, one collection each, tenant isolation | `scaling-data-volume/tenant-scaling/SKILL.md` |
| Only recent data matters, retention, expiring old vectors, time-based rotation | `scaling-data-volume/sliding-time-window/SKILL.md` |
| Single node no longer fits the workload, before deciding to shard | `scaling-data-volume/vertical-scaling/SKILL.md` |
| Already vertically maxed out, need more nodes, resharding | `scaling-data-volume/horizontal-scaling/SKILL.md` |

Latency and throughput pull opposite ways on segment count. For latency,
increase segments toward the CPU core count (`default_segment_number: 16`).
For throughput, use fewer and larger segments (`default_segment_number: 2`).
Applying the wrong direction makes the reported problem worse.
