---
name: qdrant-scaling-qps
description: "Guides Qdrant query throughput (QPS) scaling. Use when someone asks 'how to increase QPS', 'need more throughput', 'queries per second too low', 'batch search', 'read replicas', or 'how to handle more concurrent queries'."
---

# Scaling for Query Throughput (QPS)

Throughput scaling means handling more parallel queries per second. 
This is different from latency. Segment count pulls throughput and latency in opposite directions, so pick a priority per collection.

High throughput favors fewer, larger segments so each query touches less overhead.


## Performance Tuning for Higher RPS

- Use fewer, larger segments (`default_segment_number: 2`) [Maximizing throughput](https://skills.qdrant.tech/md/documentation/ops-optimization/optimize/?s=maximizing-throughput)
- Enable quantization pinned in RAM to reduce disk IO: `memory: pinned` on Qdrant 1.19 or newer, `always_ram: true` on 1.18 or older [Quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/)
- Use batch search API to amortize overhead [Batch search](https://skills.qdrant.tech/md/documentation/search/search/?s=batch-search-api)
- Prefer gRPC over REST for high-QPS workloads -- lower per-request overhead and connection multiplexing

## Minimize impact of Update Workloads

- Keep searches off unindexed data during heavy writes: the `indexed_only` search parameter, or the experimental `prevent_unoptimized` optimizer setting (v1.17.1+) [Query indexed data only](https://skills.qdrant.tech/md/documentation/search/low-latency-search/?s=query-indexed-data-only)
- Set `optimizer_cpu_budget` to limit indexing CPUs (e.g. `2` on an 8-CPU node reserves 6 for queries)
- Delayed read fan-outs (v1.17+) cut tail latency by sending extra reads to other replicas, which adds read load; leave them off when throughput is the priority [Delayed fan-outs](https://skills.qdrant.tech/md/documentation/search/low-latency-search/?s=use-delayed-fan-outs)



## Horizontal Scaling for Throughput

If a single node is saturated on CPU after applying the tuning above, scale horizontally with read replicas.

- Shard replicas serve queries from replicated shards, distributing read load across nodes
- Each replica adds independent query capacity without re-sharding
- Use `replication_factor: 2+` and send requests through a load balancer across all nodes; if every request hits one node, its local replicas serve the query and the other replicas sit idle [Deploy behind a load balancer](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=deploy-behind-a-load-balancer)

See also [Horizontal Scaling](../scaling-data-volume/horizontal-scaling/SKILL.md) for general horizontal scaling guidance.


## Disk I/O Bottlenecks

If it is not possible to keep all vectors in RAM, disk I/O can become the bottleneck for throughput. 
In this case:

- Upgrade to provisioned IOPS or local NVMe first. See impact of disk performance to vector search in [Disk performance article](https://skills.qdrant.tech/md/articles/memory-consumption/)
- Enable async I/O: `storage.performance.io_uring: auto` on Qdrant 1.19 or newer, `async_scorer: true` on 1.18 or older. Requires Linux with a kernel that supports `io_uring` [Async I/O](https://skills.qdrant.tech/md/documentation/ops-configuration/memory-tiers/?s=async-io)
- Use `datatype: turbo4` to store vectors in 4-bit on-disk representation (8x smaller), drastically reducing disk reads [turbo4](https://skills.qdrant.tech/md/documentation/manage-data/vectors/?s=turbo4)
- In case of quantized vectors, prefer global rescoring over per-segment rescoring to reduce disk reads. Example in the [tutorial](https://skills.qdrant.tech/md/documentation/tutorials-operations/large-scale-search/?s=search-query)
- Raise `max_search_threads` to parallelize disk reads. The default (`0`, automatic) suits RAM-based search but may be too low for disk-based search. See [configuration reference](https://skills.qdrant.tech/md/documentation/ops-configuration/configuration/?s=configuration-options)
- Use the slow request log (v1.16+, always on, per node) to find which queries are slowest, then check `process_major_page_faults_total` in `/metrics` to confirm I/O is the bottleneck [Slow request log](https://skills.qdrant.tech/md/documentation/ops-monitoring/slow-request-log/) [Node metrics](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/?s=node-metrics-metrics)
- If still saturated, scale out horizontally (each node adds independent IOPS)


## What NOT to Do

- Do not expect one segment configuration to maximize both throughput and latency: pick a priority per collection
- Do not use many small segments for throughput workloads (increases per-query overhead)
- Do not scale horizontally when IOPS-bound without also upgrading disk tier
- Do not run at >90% RAM (OS cache eviction = severe performance degradation)
