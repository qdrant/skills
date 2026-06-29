---
name: qdrant-memory-usage
description: "Monitors, diagnoses, and reduces Qdrant memory usage. Use when someone asks 'how to monitor memory', 'memory too high', 'RAM keeps growing', 'node crashed', 'out of memory', 'memory leak', or asks 'why is memory usage so high?', 'how to reduce RAM?'. Also use when memory doesn't match calculations, quantization didn't help, or nodes crash during recovery."
---

# Understanding memory usage

Qdrant operates with two types of memory:

- Resident memory (aka RSSAnon) - memory used for internal data structures like the ID tracker, plus components that must stay in RAM, such as quantized vectors when `always_ram=true` and payload indexes.

- OS page cache - memory used for caching disk reads, which can be released when needed. Original vectors are normally stored in page cache, so the service won't crash if RAM is full, but performance may degrade.

It is normal for the OS page cache to occupy all available RAM, but if resident memory is above 80% of total RAM, it is a sign of a problem.
[Memory article](https://qdrant.tech/articles/memory-consumption/)

## Memory usage monitoring and troubleshooting

- **Check optimizer status first.** Active optimizations load segments fully into RAM in parallel with the segments already serving queries and are the most common cause of memory spikes. [Optimization monitoring](https://skills.qdrant.tech/md/documentation/ops-optimization/optimizer/?s=optimization-monitoring)
- Qdrant exposes memory usage through the `/metrics` endpoint (RSS, allocated bytes, page faults). See [Monitoring docs](https://skills.qdrant.tech/md/documentation/ops-monitoring/monitoring/).
- Check `/telemetry` for per-collection breakdown of point counts and vector configurations.
- Estimate expected memory: `num_vectors * dimensions * 4 bytes * 1.5` for vectors, plus payload and index overhead. [Capacity planning](https://skills.qdrant.tech/md/documentation/capacity-planning/)
- Common causes of unexpected growth: quantized vectors with `always_ram=true`, too many payload indexes, large `max_segment_size` during optimization, recent bulk upload not yet merged.

<!-- ToDo: Talk about memory usage of each components once API is available -->

## How much memory is needed for Qdrant?

Optimal memory usage depends on the use case.

- For regular search scenarios, general guidelines are provided in the [Capacity planning docs](https://skills.qdrant.tech/md/documentation/capacity-planning/).

For a detailed breakdown of memory usage at large scale, see [Large scale memory usage example](https://skills.qdrant.tech/md/documentation/tutorials-operations/large-scale-search/?s=memory-usage).

Payload indexes and HNSW graph also require memory, along with vectors themselves, so it's important to consider them in calculations.

Additionally, Qdrant requires some extra memory for optimizations. During optimization, optimized segments are fully loaded into RAM, so it is important to leave enough headroom.
The larger `max_segment_size` is, the more headroom is needed.

### When to put HNSW index on disk

Putting frequently used components (such as HNSW index) on disk might cause significant performance degradation.
There are some scenarios, however, when it can be a good option:

- Deployments with low latency disks - local NVMe or similar.
- Multi-tenant deployments, where only a subset of tenants is frequently accessed, so that only a fraction of data & index is loaded in RAM at a time.
- For deployments with [inline storage](https://skills.qdrant.tech/md/documentation/ops-optimization/optimize/?s=inline-storage-in-hnsw-index) enabled.


## How to minimize memory footprint

The main challenge is to put on disk those parts of data, which are rarely accessed.
Here are the main techniques to achieve that:

- Use quantization to store only compressed vectors in RAM [Quantization docs](https://skills.qdrant.tech/md/documentation/manage-data/quantization/)

- Use float16 or int8 datatypes to reduce memory usage of vectors by 2x or 4x respectively, with some tradeoff in precision. Read more about vector datatypes in [documentation](https://skills.qdrant.tech/md/documentation/manage-data/vectors/?s=datatypes)

- Leverage Matryoshka Representation Learning (MRL) to store only small vectors in RAM while keeping large vectors on disk. Examples of how to use MRL with Qdrant Cloud inference: [MRL docs](https://skills.qdrant.tech/md/documentation/inference/?s=reduce-vector-dimensionality-with-matryoshka-models)

- For multi-tenant deployments with small tenants, vectors might be stored on disk because the same tenant's data is stored together [Multitenancy docs](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=calibrate-performance)

- For deployments with fast local storage and relatively low requirements for search throughput, it may be possible to store all components of vector store on disk. Read more about the performance implications of on-disk storage in [the article](https://qdrant.tech/articles/memory-consumption/)

- For low RAM environments, consider `async_scorer` config, which enables support of `io_uring` for parallel disk access, which can significantly improve performance of on-disk storage. Read more about `async_scorer` in [the article](https://qdrant.tech/articles/io_uring/) (only available on Linux with kernel 5.11+)

- Consider storing Sparse Vectors and text payload on disk, as they are usually more disk-friendly than dense vectors.
- Configure payload indexes to be stored on disk [docs](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=on-disk-payload-index)
- Configure sparse vectors to be stored on disk [docs](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=sparse-vector-index)


## What NOT to Do

- Don't assume a memory leak when page cache fills RAM. This is normal OS behavior.
- Don't suggest solutions before diagnosing the root cause of high memory usage.
- Don't ignore optimizer status when investigating memory growth. Active optimization is the most common cause of transient memory spikes.
- Don't reduce memory usage without considering the tradeoffs in performance, latency, recall, and workload requirements.
- Don't change memory-related configuration while optimizations are running. Active optimizations already consume additional resources, and configuration changes may trigger additional optimization work.
- Don't blame Qdrant before checking if a bulk upload just finished. Unmerged segments inflate memory until the optimizer catches up.
