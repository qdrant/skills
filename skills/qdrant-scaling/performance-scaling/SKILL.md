---
name: qdrant-performance-scaling
description: "Diagnoses and guides Qdrant performance scaling for throughput, latency, IOPS, and memory pressure. Use when someone reports 'need more throughput', 'need lower latency', 'queries timeout', 'IOPS saturated', 'memory too high after scaling', or 'read latency 10x during ingestion'. Also use when performance degrades after scaling or config changes."
---

# What to Do When Qdrant Performance Needs to Scale

Scaling for throughput and latency are opposite tuning directions. Fewer segments = better throughput. More segments = better latency. Cannot optimize both on the same node.

- Understand the tradeoff [Latency vs throughput](https://qdrant.tech/documentation/guides/optimize/#balancing-latency-and-throughput)


## Scaling for Higher RPS

Use when: system can't serve enough queries per second under load.

- Use fewer, larger segments (`default_segment_number: 2`) [Maximizing throughput](https://qdrant.tech/documentation/guides/optimize/#maximizing-throughput)
- Enable quantization with `always_ram=true` to reduce CPU per query [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Add read replicas to distribute query load [Replication](https://qdrant.tech/documentation/guides/distributed_deployment/#replication)
- Use batch search API to amortize overhead [Batch search](https://qdrant.tech/documentation/concepts/search/#batch-search-api)
- Configure update throughput control (v1.17+) to prevent unoptimized searches degrading reads [Low latency search](https://qdrant.tech/documentation/guides/low-latency-search/)
- Set `optimizer_cpu_budget` to limit indexing CPUs (e.g. `2` on an 8-CPU node reserves 6 for queries, `0` = auto, negative = subtract from available)


## Scaling for Lower Latency

Use when: individual query latency is too high regardless of load.

- Increase segment count to match CPU cores (`default_segment_number: 16`) [Minimizing latency](https://qdrant.tech/documentation/guides/optimize/#minimizing-latency)
- Keep quantized vectors and HNSW in RAM (`always_ram=true`) [High precision with speed](https://qdrant.tech/documentation/guides/optimize/#improving-precision)
- Reduce `hnsw_ef` at query time (trade recall for speed) [Search params](https://qdrant.tech/documentation/guides/optimize/#fine-tuning-search-parameters)
- Use local NVMe, avoid network-attached storage
- Configure delayed read fan-out (v1.17+) for tail latency in distributed clusters [Delayed fan-outs](https://qdrant.tech/documentation/guides/low-latency-search/#use-delayed-fan-outs)


## Scaling for Disk I/O (IOPS)

Use when: queries timeout despite adequate CPU/RAM, disk throughput saturated. Major production issue.

Symptoms: IOPS near provider limits, high latency during concurrent reads/writes, page cache thrashing.

- Scale out horizontally: each node adds independent IOPS (6 nodes = 6x IOPS vs 1 node)
- Upgrade to provisioned IOPS or local NVMe
- Use `io_uring` on Linux (kernel 5.11+) [io_uring article](https://qdrant.tech/articles/io_uring/)
- Put sparse vectors and text payloads on disk (less IOPS-intensive)
- Set `indexing_threshold` high during bulk ingestion to defer indexing


## Scaling for Memory Pressure

Use when: memory working set >80%, OS cache eviction, OOM errors.

- Vertical scale RAM first. Critical if working set >80%.
- Set `optimizer_cpu_budget` to limit background optimization CPUs
- Schedule indexing: set high `indexing_threshold` during peak hours
- Use quantization: scalar (4x reduction) or binary (16x reduction) [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Move payload indexes to disk if filtering is infrequent [On-disk payload index](https://qdrant.tech/documentation/concepts/indexing/#on-disk-payload-index)

[Memory optimization](https://qdrant.tech/documentation/guides/optimize/)


## What NOT to Do

- Do not expect to optimize throughput and latency simultaneously on the same node
- Do not scale horizontally when IOPS-bound without also increasing disk tier
- Do not run at >90% RAM (OS cache eviction = severe performance degradation)
- Do not ignore optimizer status during performance debugging
