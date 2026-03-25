---
name: qdrant-memory-usage-optimization
description: "Diagnoses and reduces Qdrant memory usage. Use when someone reports 'memory too high', 'RAM keeps growing', 'node crashed', 'out of memory', 'memory leak', or asks 'why is memory usage so high?', 'how to reduce RAM?'. Also use when memory doesn't match calculations, quantization didn't help, or nodes crash during recovery."
---

# What to Do When Qdrant Uses Too Much Memory

Qdrant uses two types of RAM: resident memory (RSSAnon) for data structures, quantized vectors, payload indexes, and OS page cache for caching disk reads. Page cache filling all available RAM is normal. If resident memory exceeds 80% of total RAM, investigate.

- Understand memory breakdown [Memory article](https://qdrant.tech/articles/memory-consumption/)


## Don't Know What's Using Memory

Use when: memory is higher than expected and you need to find the cause.

- Check `/metrics` for process-level memory (RSS, allocated bytes, page faults) [Monitoring docs](https://qdrant.tech/documentation/guides/monitoring/)
- Use `/telemetry` for per-segment breakdown: `ram_usage_bytes`, `vectors_size_bytes`, `payloads_size_bytes` per segment
- Estimate expected memory: `num_vectors * dimensions * 4 bytes * 1.5` plus payload and index overhead [Capacity planning](https://qdrant.tech/documentation/guides/capacity-planning/)
- For large scale reference [Large scale memory example](https://qdrant.tech/documentation/tutorials-operations/large-scale-search/#memory-usage)
- Common causes of unexpected growth: quantized vectors with `always_ram=true`, too many payload indexes, large `max_segment_size` during optimization


## Memory Too High for Dataset Size

Use when: resident memory exceeds what the dataset should need.

- Use quantization to store compressed vectors in RAM [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Use float16 or uint8 datatypes to reduce vector memory by 2x or 4x [Datatypes](https://qdrant.tech/documentation/concepts/vectors/#datatypes)
- Use Matryoshka models to store smaller vectors in RAM, larger on disk [MRL](https://qdrant.tech/documentation/concepts/inference/#reduce-vector-dimensionality-with-matryoshka-models)
- Move payload indexes to disk if filtering is infrequent [On-disk payload index](https://qdrant.tech/documentation/concepts/indexing/#on-disk-payload-index)
- Move sparse vectors to disk [Sparse vector index](https://qdrant.tech/documentation/concepts/indexing/#sparse-vector-index)

Payload indexes and HNSW graph also consume memory. Include them in calculations. During optimization, segments are fully loaded into RAM. Larger `max_segment_size` means more headroom needed.


## Want Everything on Disk

Use when: RAM budget is very tight and you accept slower search.

- Store all vector components on disk with mmap [On-disk storage](https://qdrant.tech/articles/memory-consumption/)
- For multi-tenant deployments with small tenants, on-disk works well since same-tenant data is co-located [Multitenancy](https://qdrant.tech/documentation/guides/multitenancy/#calibrate-performance)
- Enable `async_scorer` with `io_uring` for parallel disk access on Linux (kernel 5.11+) [io_uring](https://qdrant.tech/articles/io_uring/)
- Consider inline HNSW storage [Inline storage](https://qdrant.tech/documentation/guides/optimize/#inline-storage-in-hnsw-index)

HNSW on disk causes significant performance degradation except: local NVMe, multi-tenant with partial access patterns, or inline storage enabled.


## What NOT to Do

- Assume memory leak when page cache fills RAM (normal OS behavior)
- Put HNSW on disk for latency-sensitive production without NVMe
- Ignore `max_segment_size` headroom during optimization (causes temporary OOM)
- Run at >90% resident memory (cache eviction causes severe performance degradation)
- Create payload indexes on every field (each index consumes memory)
