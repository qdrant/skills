---
name: qdrant-sliding-time-window
description: "Guides sliding time window scaling in Qdrant. Use when someone asks 'only recent data matters', 'how to expire old vectors', 'time-based data rotation', 'delete old data efficiently', 'social media feed search', 'news search', 'log search with retention', 'how to keep only last N months of data', or when delete-by-filter cleanup causes slowdowns. Crucial because delete-by-filter leaves tombstones and reclaims no disk, whereas dropping a shard key reclaims disk and resources instantly."
---

# Scaling with a Sliding Time Window

Use when only recent data needs fast search -- social media posts, news articles, support tickets, logs, job listings. Old data either becomes irrelevant or can tolerate slower access.

Three strategies: **shard rotation** (recommended), **collection rotation** (when per-period config differs), and **filter-and-delete** (simplest, for continuous cleanup).


## Shard Rotation (Recommended)

Use when: data has natural time boundaries (daily, weekly, monthly). Preferred because queries span all time periods in one request without application-level fan-out. [User-defined sharding](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=user-defined-sharding)

Create one shard key per time period, write to the current one, and delete the oldest shard key once it leaves the retention window. The [Time-Based Sharding tutorial](https://skills.qdrant.tech/md/documentation/tutorials-operations/time-based-sharding/) walks through the setup.

- Deleting a shard key reclaims all resources instantly (no fragmentation, no optimizer overhead)
- Pre-create the next period's shard key before rotation to avoid write disruption
- Use `shard_key_selector` at query time to search only specific periods for efficiency
- Shard keys can be placed on specific nodes for hot/cold tiering


## Collection Rotation (Alias Swap)

Use when: you need per-period collection configuration (e.g., different quantization or storage settings). [Collection aliases](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=collection-aliases)

Create one collection per period behind a write alias, swap the alias to the new collection when a period starts [Switch collection](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=switch-collection), and drop the oldest collection outside the window. Queries must fan out across all active collections in parallel and merge results client-side.

Trade-off vs shard rotation: allows per-collection config differences, but requires application-level fan-out and more operational overhead.


## Filter-and-Delete

Use when: data arrives continuously without clear time boundaries, or you want the simplest setup.

1. Store the timestamp as a `datetime` payload on every point and index it [Payload index](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index)
2. Filter to the desired window at query time with a datetime range condition [Datetime range](https://skills.qdrant.tech/md/documentation/search/filtering/?s=datetime-range)
3. Periodically delete expired points using delete-by-filter [Delete points](https://skills.qdrant.tech/md/documentation/manage-data/points/?s=delete-points)

- Run cleanup during off-peak hours in batches (10k-50k points) to avoid optimizer locks
- Deletes are not free: tombstoned points degrade search until optimizer compacts segments
- Does not reclaim disk instantly (compaction is asynchronous)


## Hot/Cold Tiers

Use when: recent data needs fast in-RAM search, older data should remain searchable at lower performance.

- **Shard rotation:** place current shard key on fast-storage nodes, move older shard keys to cheaper nodes via shard placement. All queries still go through a single collection.
- **Collection rotation:** keep the current collection's quantized vectors in RAM (`memory: pinned` on Qdrant 1.19 or newer, `always_ram: true` on 1.18 or older) and its dense vectors in page cache (`memory: cached`, the default; Qdrant rejects `pinned` for dense vectors), move older collections to mmap/on-disk vectors (`memory: cold` on 1.19 or newer, `on_disk: true` on 1.18 or older). [Quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/)


## What NOT to Do

- Do not use filter-and-delete for high-volume time-series with millions of daily deletes (use rotation instead)
- Do not forget to index the timestamp field (range filters without an index cause full scans)
- Do not use collection rotation when shard rotation would suffice (unnecessary fan-out complexity)
- Do not drop a shard key or collection before verifying its period is fully outside the retention window
- Do not skip pre-creating the next period's shard key or collection (write failures during rotation are hard to recover)
