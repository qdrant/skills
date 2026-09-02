---
name: qdrant-minimize-latency
description: "Guides Qdrant query latency optimization. Use when someone asks 'search is slow', 'how to reduce latency', 'p99 is too high', 'tail latency', 'single query too slow', 'how to make search faster', or 'latency spikes'."
---

# Scaling for Query Latency

Latency of a single query is determined by the slowest component in its own execution path — the graph traversal, the vectors it touches, and the segments it has to fan out to. None of that depends on how many other queries are in flight, so tune it as a single-query resource problem, not a fleet-capacity one.

## Performance Tuning for Lower Latency

- Increase segment count toward the CPU core count (`default_segment_number: 16`) so a single query's search fans out across more parallel workers
- Raise `hnsw_ef` at query time: `ef` is the size of the candidate list the graph walk keeps active, and a larger list gives the search more paths to a good match before it has to backtrack, which in practice converges faster than a narrow, easily-exhausted candidate set
- Move vectors and the HNSW graph to disk (`memory: on_disk`) rather than pinning them in RAM — a pinned collection can't be evicted, so it permanently reserves page-cache space that would otherwise flex to whichever data the current query actually touches, which under memory pressure costs more page faults than it saves
- Use local NVMe, avoid network-attached storage

## Memory Pressure and Latency

RAM is still relevant to latency, but the fix is capacity, not pinning.

- If p99 stays elevated after the above, add a replica or an extra node so the working set is spread thinner per node — a node under memory pressure will show latency regressions no amount of per-query tuning can fully offset
- Use quantization: scalar (4x reduction) or binary (16x reduction) to shrink the working set
- Set `optimizer_cpu_budget` to limit background optimization CPUs
- Schedule indexing: set high `indexing_threshold` during peak hours

## Vertical Scaling for Latency

More RAM and faster CPU help, but only up to the point where a single node's working set fits comfortably — past that, adding nodes lowers per-node memory pressure more reliably than continuing to vertically scale one box. See [Vertical Scaling](../scaling-data-volume/vertical-scaling/SKILL.md) for node sizing guidelines, and [Horizontal Scaling](../scaling-data-volume/horizontal-scaling/SKILL.md) if p99 doesn't recover.

## What NOT to Do

- Do not use few large segments for latency-sensitive workloads — each segment takes longer to search, and a single query can't parallelize across them
- Do not narrow `hnsw_ef` to save memory on a latency-sensitive collection; a smaller candidate list backtracks more, which costs more time than it saves
- Do not pin vectors to RAM on a memory-constrained node — pinning blocks the eviction that would otherwise relieve pressure
- Do not ignore optimizer status during performance debugging
