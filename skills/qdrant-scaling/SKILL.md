---
name: qdrant-scaling
description: "Guides Qdrant scaling decisions. Use when someone asks 'how many nodes do I need', 'data doesn't fit on one node', 'need more throughput or QPS', 'CPU is pegged / can't keep up with the request rate', 'one query is slow / p99 or tail latency too high', 'cluster is slow', 'too many tenants', 'vertical or horizontal', 'how to shard', 'need to add capacity', 'large limit / pagination / scroll is slow', or 'only recent data matters / expiring old vectors / retention window'."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Scaling

Route first, then answer. Match the user's symptom in the table, `Read` that file, and answer from it.
Do not answer from this page alone: it contains routing only, not the guidance. If two rows match, read both.

| The user says | Read |
|---|---|
| Data does not fit on a single node, running out of disk or memory as the dataset grows | `scaling-data-volume/SKILL.md` |
| Need to shard the collection across more nodes, data outgrew one node | `scaling-data-volume/SKILL.md` |
| Cannot handle enough parallel queries, need higher QPS or throughput | `scaling-qps/SKILL.md` |
| Can't hold the request rate, CPU is pegged | `scaling-qps/SKILL.md` |
| A single query is too slow, need to cut the tail latency of individual requests | `minimize-latency/SKILL.md` |
| p99 or tail latency too high, but traffic/QPS is fine | `minimize-latency/SKILL.md` |
| Queries return very large result sets and slow down | `scaling-query-volume/SKILL.md` |
| Large `limit`, top-1000 queries, pagination, scroll across shards | `scaling-query-volume/SKILL.md` |
| Many tenants or customers, one collection each, tenant isolation | `scaling-data-volume/tenant-scaling/SKILL.md` |
| Only recent data matters, retention, expiring old vectors, time-based rotation | `scaling-data-volume/sliding-time-window/SKILL.md` |
| Single node no longer fits the workload, before deciding to shard | `scaling-data-volume/vertical-scaling/SKILL.md` |
| Already vertically maxed out, need more nodes, resharding | `scaling-data-volume/horizontal-scaling/SKILL.md` |

Latency and throughput pull opposite ways on segment count.
For latency, increase segments toward the CPU core count (`default_segment_number: 16`).
For throughput, use fewer and larger segments (`default_segment_number: 2`).
Applying the wrong direction makes the reported problem worse.
