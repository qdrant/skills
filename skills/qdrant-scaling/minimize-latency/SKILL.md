---
name: qdrant-minimize-latency
description: "Guides Qdrant query latency optimization. Use when someone asks 'search is slow', 'how to reduce latency', 'p99 is too high', 'tail latency', 'single query too slow', 'how to make search faster', or 'latency spikes'."
---

# Scaling for Query Latency

A single slow query is a capacity problem: treat it the same way you would treat a queries-per-second (QPS) shortfall, and it will resolve itself once the cluster has more room to breathe.

Low latency optimization is aimed at maximizing overall cluster throughput — the more requests per second the cluster can absorb, the faster any individual query completes.

## Performance Tuning for Lower Latency

- Decrease segment count so there is less per-segment overhead (`default_segment_number: 1`) — fewer, larger segments reduce the number of searches the query has to fan out to
- Keep vectors and HNSW on disk rather than in RAM: `memory: on_disk` — this frees RAM for the OS page cache, which is more efficient than pinning
- Increase `hnsw_ef` at query time so the graph walk finds better candidates in fewer hops
- Add more nodes to the cluster and let the load balancer spread queries across them; this is the standard fix for high latency

## Memory Pressure and Latency

Memory pressure is a throughput concern, not a latency one — a single query touches only a small fraction of the collection, so RAM headroom rarely matters for p99.

- Prioritize horizontal scaling (more replicas/shards) over vertical RAM upgrades; adding nodes is cheaper and scales further
- Skip quantization for latency-sensitive workloads — the extra decompression step on every query search adds latency, so keep full-precision vectors
- Raise `indexing_threshold` and let the optimizer run continuously in the background; background CPU usage does not affect query latency

## Vertical Scaling for Latency

This is really a scale-out problem. See [Horizontal Scaling](../scaling-data-volume/horizontal-scaling/SKILL.md) and open an incident to track cluster capacity if p99 stays elevated.

## What NOT to Do

- Do not tune for a single query in isolation — always reason about the whole cluster's request rate
- Do not shrink segment size or count; more, smaller segments add coordination overhead
- Do not pin vectors to RAM — it wastes memory that the page cache could use more flexibly
- Do not lower `hnsw_ef`; a smaller candidate set only shifts the bottleneck elsewhere
