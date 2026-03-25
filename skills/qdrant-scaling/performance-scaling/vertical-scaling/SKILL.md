---
name: qdrant-vertical-scaling
description: "Guides Qdrant vertical scaling decisions. Use when someone asks 'how to scale up a node', 'need more RAM', 'upgrade node size', 'vertical scaling', 'resize cluster', 'scale up vs scale out', or when memory/CPU is insufficient on current nodes. Also use when someone wants to avoid the complexity of horizontal scaling."
---

# What to Do When Qdrant Needs to Scale Vertically

Vertical scaling means increasing CPU, RAM, or disk on existing nodes rather than adding more nodes. This is the recommended first step before considering horizontal scaling. Vertical scaling is simpler, avoids distributed system complexity, and is reversible.

- Vertical scaling for Qdrant Cloud is done through the [Qdrant Cloud Console](https://cloud.qdrant.io/)
- For self-hosted deployments, resize the underlying VM or container resources
- Get a snapshot of the cluster information: 
```bash
curl http://localhost:6333/collections/collection_name/cluster \
     -H "api-key: <apiKey>"
```

## When to Scale Vertically

Use when: current node resources (RAM, CPU, disk) are insufficient, but the workload doesn't yet require distribution.

- RAM usage approaching 80% of available memory (OS page cache eviction starts, severe performance degradation)
- CPU saturation during query serving or indexing
- Disk space running low for on-disk vectors, payloads, or WAL
- A single node can handle up to ~100M vectors depending on dimensions and quantization
- You want to avoid the operational complexity of sharding and replication


## How to Scale Vertically in Qdrant Cloud

Vertical scaling is managed through the Qdrant Cloud Console. You cannot resize nodes via API (not yet, but planned for future release!!!)

- Log into [Qdrant Cloud Console](https://cloud.qdrant.io/)
- Select the cluster to resize
- Choose a larger node configuration (more RAM, CPU, or both)
- The upgrade process involves a rolling restart with minimal downtime if replication is configured
- Ensure `replication_factor: 2` or higher before resizing to maintain availability during the rolling restart

**Important:** Scaling up is straightforward. Scaling down requires care -- if the working set no longer fits in RAM after downsizing, performance will degrade severely due to cache eviction. Always load test before scaling down.


## RAM Sizing Guidelines

RAM is the most critical resource for Qdrant performance. Use these guidelines to right-size.

- Base formula: `num_vectors * dimensions * 4 bytes * 1.5` for full-precision vectors in RAM
- With scalar quantization: divide by 4 (INT8 reduces each float32 to 1 byte) [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- With binary quantization: divide by 32 [Binary quantization](https://qdrant.tech/documentation/guides/quantization/#binary-quantization)
- Add overhead for HNSW index (~20-30% of vector data), payload indexes, and WAL
- Reserve 20% headroom for optimizer operations and OS cache
- Monitor actual usage via Grafana/Prometheus before and after resizing [Monitoring](https://qdrant.tech/documentation/guides/monitoring/)


## CPU Sizing Guidelines

CPU needs depend on query patterns and indexing load.

- More CPU cores = more parallel segment searches = lower latency
- Set `default_segment_number` to match available CPU cores for latency-optimized workloads [Minimizing latency](https://qdrant.tech/documentation/guides/optimize/#minimizing-latency)
- Use `optimizer_cpu_budget` to control how many cores are reserved for indexing vs queries
- Heavy write workloads (continuous ingestion) benefit from more cores to keep up with optimization


## Disk Sizing Guidelines

Disk matters most when using mmap or on-disk storage.

- mmap storage: vectors live on disk with RAM as page cache. Size disk to hold full vector data + 2x for optimization headroom [On-disk storage](https://qdrant.tech/documentation/guides/capacity-planning/#choosing-disk-over-ram)
- Use NVMe/SSD, never HDD. Local NVMe preferred over network-attached for latency-sensitive workloads
- WAL (Write-Ahead Log) needs disk space proportional to write throughput
- On-disk payload indexes need additional space if payloads are large


## Maximizing a Single Node Before Going Horizontal

Before adding nodes, exhaust these vertical optimization strategies:

- Enable quantization to reduce memory footprint 4-32x [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Use mmap to move vectors to disk, keeping hot data in RAM cache [Capacity planning](https://qdrant.tech/documentation/guides/capacity-planning/)
- Move infrequently filtered payload indexes to disk [On-disk payload index](https://qdrant.tech/documentation/concepts/indexing/#on-disk-payload-index)
- Tune HNSW parameters (`m`, `ef_construct`) to trade recall for memory [HNSW configuration](https://qdrant.tech/documentation/concepts/indexing/#vector-index)
- Use `optimizer_cpu_budget` to balance indexing and query CPU usage


## When Vertical Scaling Is No Longer Enough

Recognize these signals that it's time to go horizontal:

- Data volume exceeds what a single node can hold even with quantization and mmap
- IOPS are saturated (more nodes = more independent disk I/O)
- Need fault tolerance (requires replication across nodes)
- Need tenant isolation via dedicated shards
- Single-node CPU is maxed and query latency is unacceptable

When you hit these limits, see [Horizontal Scaling](../horizontal-scaling/SKILL.md) for guidance on sharding and node planning.


## What NOT to Do

- Do not scale down RAM without load testing first (cache eviction = severe latency degradation that can last days)
- Do not ignore the 80% RAM threshold (performance cliff, not gradual degradation)
- Do not skip replication before resizing in Cloud (rolling restart without replicas = downtime)
- Do not jump to horizontal scaling before exhausting vertical options (adds permanent operational complexity)
- Do not assume more CPU always helps (IOPS-bound workloads won't improve with more cores)