---
name: qdrant-indexing-performance-optimization
description: "Diagnoses and fixes slow Qdrant indexing and data ingestion. Use when someone reports 'uploads are slow', 'indexing takes forever', 'optimizer is stuck', 'HNSW build time too long', or 'data uploaded but search is bad'. Also use when optimizer status shows errors, segments won't merge, or indexing threshold questions arise."
---

# What to Do When Qdrant Indexing Is Too Slow

Qdrant does NOT build HNSW indexes immediately. Small segments use brute-force until they exceed `indexing_threshold_kb` (default: 10000 KB, about 10 MB). Search during this window is slower by design, not a bug.

- Understand the indexing optimizer [Indexing optimizer](https://skills.qdrant.tech/md/documentation/ops-optimization/optimizer/?s=indexing-optimizer)


## Uploads/Ingestion Too Slow

Use when: upload or upsert API calls are slow.
Identify bottleneck: client-side (network, batching) vs server-side (CPU, disk I/O)

For client-side, optimize batching and parallelism:

- Use batch upserts (64-256 points per request) and 2-4 parallel upload streams [Bulk upload](https://skills.qdrant.tech/md/documentation/manage-data/bulk-upload/)

For server-side, optimize Qdrant configuration and indexing strategy:

- Create 2 to 4 shards per machine; each shard has an independent update worker, so give each one its own upload stream [Multiple shards](https://skills.qdrant.tech/md/documentation/manage-data/bulk-upload/?s=create-collections-with-multiple-shards)
- Create payload indexes before HNSW builds (needed for filterable vector index) [Payload index](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index)


## Optimizer Stuck or Taking Too Long

Use when: optimizer running for hours, not finishing.

- Check actual progress via optimizations endpoint (v1.17+) [Optimization monitoring](https://skills.qdrant.tech/md/documentation/ops-optimization/optimizer/?s=optimization-monitoring)
- Large merges and HNSW rebuilds legitimately take hours on big datasets
- Check CPU and disk I/O (HNSW is CPU-bound, merging is I/O-bound, HDD is not viable)
- If `optimizer_status` shows an error, check logs for disk full or corrupted segments


## HNSW Build Time Too High

Use when: HNSW index build dominates total indexing time.

- Reduce `m` (default 16, good for most cases, 32+ rarely needed) [HNSW params](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=vector-index)
- Reduce `ef_construct` (100-200 sufficient) [HNSW params](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=vector-index)
- Leave `max_indexing_threads` at 0 (auto) or cap it; the configuration reference suggests 8 to 16 [Configuration](https://skills.qdrant.tech/md/documentation/ops-configuration/configuration/)
- Use GPU for indexing (v1.13+): run a `gpu-nvidia` or `gpu-amd` image tag (e.g. `qdrant/qdrant:gpu-nvidia-latest`) on a Vulkan 1.3 GPU and set `gpu.indexing: true` [GPU indexing](https://skills.qdrant.tech/md/documentation/ops-configuration/running-with-gpu/)

## HNSW Index for Multi-Tenant Collections

Use when: every query filters by a tenant field and the global HNSW build dominates indexing time.

- Skip the global HNSW and build per-tenant graphs: at collection creation, set `payload_m` to a non-zero value, then `m: 0`. Queries without a tenant filter get slower, so only do this when cross-tenant search is rare [Calibrate performance](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=calibrate-performance)

## Additional Payload Indexes Are Too Slow

Use when: HNSW builds slowly after adding payload indexes, especially on high-cardinality fields such as long `text`.

- Qdrant adds extra HNSW links for every payload index so filtered search keeps its quality. For a field with many unique values per point, disable those links and rely on the slower query-time [ACORN](https://skills.qdrant.tech/md/documentation/search/search/?s=acorn-search-algorithm) strategy instead [Disable extra edges](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=disable-the-creation-of-extra-edges-for-payload-fields)


## What NOT to Do

- Do not create payload indexes AFTER HNSW is built without triggering a re-index afterward -- filterable HNSW edges won't exist for the new index until segments are re-optimized
- Do not use `m=0` for bulk uploads into an existing collection, it might drop the existing HNSW and cause long reindexing 
- Do not upload one point at a time (per-request overhead dominates)
