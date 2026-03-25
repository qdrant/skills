---
name: qdrant-performance-scaling
description: "Guides Qdrant scaling decisions for capacity and performance. Use when someone asks about vertical vs horizontal scaling, node sizing, throughput, latency, IOPS, memory pressure, 'how to scale Qdrant', 'need more capacity', or when performance degrades. Routes to vertical scaling, horizontal scaling, or performance tuning as appropriate."
---

# Scaling Qdrant for Performance and Capacity

Scaling Qdrant means either scaling **up** (vertical -- bigger nodes) or scaling **out** (horizontal -- more nodes). The right choice depends on what you're scaling for and where you are in your growth trajectory.

**Start vertical, go horizontal only when you must.** Horizontal scaling adds permanent operational complexity -- sharding, replication, rebalancing, network overhead -- and is effectively a one-way street. Once you distribute data across nodes, consolidating back to fewer nodes is difficult and risky. Vertical scaling is simpler, reversible, and sufficient for most workloads up to ~100M vectors per node.


## Scaling Dimensions

Different scaling needs pull in different directions. Identify your primary constraint before choosing a strategy.

- **Data volume:** How much data needs to fit? RAM, disk, and quantization are the levers. Start with vertical (bigger nodes, quantization, mmap). Go horizontal only when a single node can't hold the data or when you need fault tolerance/isolation.
- **Query throughput (QPS):** How many queries per second? Fewer segments, quantization with `always_ram=true`, and batch APIs help. Read replicas scale this horizontally.
- **Query latency:** How fast must individual queries respond? More segments (matching CPU cores), in-RAM quantized vectors, and lower `hnsw_ef`. Throughput and latency are opposite tuning directions -- you cannot optimize both on the same node.
- **Tenant count:** How many tenants share the cluster? Use payload partitioning with `is_tenant=true`. See [Tenant Scaling](../tenant-scaling/SKILL.md).

Understand the core tradeoff: [Latency vs throughput](https://qdrant.tech/documentation/guides/optimize/#balancing-latency-and-throughput)


## Performance Tuning (Independent of Scaling Direction)

These optimizations apply regardless of whether you scale vertically or horizontally.

### For Higher RPS

- Use fewer, larger segments (`default_segment_number: 2`) [Maximizing throughput](https://qdrant.tech/documentation/guides/optimize/#maximizing-throughput)
- Enable quantization with `always_ram=true` to reduce CPU per query [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Use batch search API to amortize overhead [Batch search](https://qdrant.tech/documentation/concepts/search/#batch-search-api)
- Configure update throughput control (v1.17+) to prevent unoptimized searches degrading reads [Low latency search](https://qdrant.tech/documentation/guides/low-latency-search/)
- Set `optimizer_cpu_budget` to limit indexing CPUs (e.g. `2` on an 8-CPU node reserves 6 for queries)

### For Lower Latency

- Increase segment count to match CPU cores (`default_segment_number: 16`) [Minimizing latency](https://qdrant.tech/documentation/guides/optimize/#minimizing-latency)
- Keep quantized vectors and HNSW in RAM (`always_ram=true`)
- Reduce `hnsw_ef` at query time (trade recall for speed) [Search params](https://qdrant.tech/documentation/guides/optimize/#fine-tuning-search-parameters)
- Use local NVMe, avoid network-attached storage
- Configure delayed read fan-out (v1.17+) for tail latency [Delayed fan-outs](https://qdrant.tech/documentation/guides/low-latency-search/#use-delayed-fan-outs)

### For Disk I/O (IOPS)

- Upgrade to provisioned IOPS or local NVMe first
- Use `io_uring` on Linux (kernel 5.11+) [io_uring article](https://qdrant.tech/articles/io_uring/)
- Put sparse vectors and text payloads on disk
- Set `indexing_threshold` high during bulk ingestion to defer indexing
- If still saturated, scale out horizontally (each node adds independent IOPS)

### For Memory Pressure

- Vertical scale RAM first. Critical if working set >80%.
- Use quantization: scalar (4x reduction) or binary (16x reduction) [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Move payload indexes to disk if filtering is infrequent [On-disk payload index](https://qdrant.tech/documentation/concepts/indexing/#on-disk-payload-index)
- Set `optimizer_cpu_budget` to limit background optimization CPUs
- Schedule indexing: set high `indexing_threshold` during peak hours


## Dedicated Scaling Guides

- **[Vertical Scaling](vertical-scaling/SKILL.md)** -- Node sizing, RAM/CPU/disk guidelines, scaling up in Qdrant Cloud, and maximizing single-node capacity before going horizontal.
- **[Horizontal Scaling](horizontal-scaling/SKILL.md)** -- Sharding, resharding, shard planning, node count decisions, and prerequisites for zero-downtime distributed scaling.


## What NOT to Do

- Do not scale horizontally before exhausting vertical options (adds permanent, irreversible complexity)
- Do not expect to optimize throughput and latency simultaneously on the same node
- Do not scale horizontally when IOPS-bound without also upgrading disk tier
- Do not run at >90% RAM (OS cache eviction = severe performance degradation)
- Do not scale down RAM without load testing (cache eviction causes days-long latency incidents)
- Do not ignore optimizer status during performance debugging