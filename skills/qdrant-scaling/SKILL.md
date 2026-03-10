---
name: qdrant-scaling
description: "Diagnoses and guides Qdrant scaling decisions. Use when someone reports 'need more capacity', 'data doesn't fit', 'need more throughput', 'need lower latency', 'how to add nodes', 'how to shard', 'need to scale tenants', or asks 'vertical or horizontal?', 'how many nodes?', 'how many shards?'. Also use when data growth outpaces current deployment or multi-tenant workloads need isolation."
---

# What to Do When Qdrant Needs to Scale

First determine what you're scaling for: data volume, query throughput (QPS), query latency, or tenant count. Each pulls toward different strategies. Scaling for throughput and latency are opposite tuning directions.

- Understand the tradeoff [Latency vs throughput](https://qdrant.tech/documentation/guides/optimize/#balancing-latency-and-throughput)


## Scaling for Larger Data Volume

Use when: dataset doesn't fit on a single node, or approaching memory/disk limits.

- Estimate memory needs: `num_vectors * dimensions * 4 bytes * 1.5` for vectors, plus payload and index overhead [Capacity planning](https://qdrant.tech/documentation/guides/capacity-planning/)
- Use quantization to reduce vector memory by 4x (scalar) or 32x (binary) [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Use mmap storage to keep vectors on disk with RAM as cache [Choosing disk over RAM](https://qdrant.tech/documentation/guides/capacity-planning/#choosing-disk-over-ram)
- If single node is not enough, distribute across nodes with sharding [Sharding](https://qdrant.tech/documentation/guides/distributed_deployment/#sharding)


## Vertical vs Horizontal Scaling

Use when: deciding between bigger nodes or more nodes.

- **Vertical first**: simpler operations, no network overhead, good up to ~100M vectors per node depending on dimensions and quantization
- **Horizontal when**: data exceeds single node capacity, need fault tolerance (replication), or need to isolate tenants on dedicated shards
- Horizontal requires distributed mode enabled [Cluster setup](https://qdrant.tech/documentation/guides/distributed_deployment/#enabling-distributed-mode-in-self-hosted-qdrant)
- Set `shard_number` as a multiple of node count for even distribution [Sharding](https://qdrant.tech/documentation/guides/distributed_deployment/#sharding)
- Add replicas for read availability and fault tolerance [Replication](https://qdrant.tech/documentation/guides/distributed_deployment/#replication)


### Resharding

Use when: you need to change shard count on an existing collection without recreating it.

- Available in Qdrant Cloud (v1.13+) [Resharding](https://qdrant.tech/documentation/guides/distributed_deployment/#resharding)
- For self-hosted, resharding requires recreating the collection with the new shard count
- Move shards between nodes dynamically to rebalance load [Moving shards](https://qdrant.tech/documentation/guides/distributed_deployment/#moving-shards)


## Scaling for Higher RPS

Use when: system can't serve enough queries per second under load.

- Use fewer, larger segments (`default_segment_number: 2`, `max_segment_size` up to 5GB) to maximize parallel request handling [Maximizing throughput](https://qdrant.tech/documentation/guides/optimize/#maximizing-throughput)
- Enable quantization with `always_ram=true` to reduce CPU per query [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Add read replicas to distribute query load [Replication](https://qdrant.tech/documentation/guides/distributed_deployment/#replication)
- Use batch search API to amortize overhead across queries [Batch search](https://qdrant.tech/documentation/concepts/search/#batch-search-api)


## Scaling for Lower Latency

Use when: individual query latency is too high regardless of load.

- Increase segment count to match CPU cores (`default_segment_number: 16`) for parallel search within a single query [Minimizing latency](https://qdrant.tech/documentation/guides/optimize/#minimizing-latency)
- Keep quantized vectors and HNSW index in RAM (`always_ram=true`) [High precision with speed](https://qdrant.tech/documentation/guides/optimize/#high-precision-with-high-speed-search)
- Reduce `hnsw_ef` at query time (trade recall for speed) [Search params](https://qdrant.tech/documentation/guides/optimize/#fine-tuning-search-parameters)
- Use local NVMe storage for on-disk components, avoid network-attached storage


## Scaling Tenants

Use when: multi-tenant workload with many isolated users sharing one deployment.

- Use payload-based partitioning with a tenant ID field and keyword index [Multitenancy](https://qdrant.tech/documentation/guides/multitenancy/#partition-by-payload)
- Set `is_tenant=true` on the tenant index to co-locate tenant data for sequential reads [Calibrate performance](https://qdrant.tech/documentation/guides/multitenancy/#calibrate-performance)
- Disable global HNSW (`m: 0`) and use `payload_m: 16` to build per-tenant indexes, dramatically faster ingestion [Calibrate performance](https://qdrant.tech/documentation/guides/multitenancy/#calibrate-performance)
- For large tenants (20k+ points), use dedicated shards via user-defined sharding [Tiered multitenancy](https://qdrant.tech/documentation/guides/multitenancy/#tiered-multitenancy)
- Small tenants share fallback shards, large tenants get promoted to dedicated shards automatically


## Scaling for Time Window Rotation

Use when: data has a time component and old data should be retired (logs, events, time-series embeddings).

- Use collection aliases to swap between active and historical collections without downtime [Collection aliases](https://qdrant.tech/documentation/concepts/collections/#collection-aliases)
- Create new collections per time window, point alias at the active one
- Delete expired collections to reclaim resources
- For queries across windows, use multi-collection search or merge results client-side


## What NOT to Do

- Jump to horizontal scaling before exhausting vertical options (adds operational complexity for no gain)
- Set `shard_number` that isn't a multiple of node count (causes uneven distribution)
- Use `replication_factor: 1` in production if you need fault tolerance
- Expect resharding on self-hosted without recreation (use Qdrant Cloud for live resharding)
- Create one collection per tenant instead of using payload partitioning (does not scale past hundreds of tenants)
