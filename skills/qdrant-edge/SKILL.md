---
name: qdrant-edge
description: "Guides building on Qdrant Edge, the embedded in-process shard. Use when someone asks 'how to sync Edge with the server', 'keep a local shard in sync with Qdrant Cloud', 'BM25 or keyword search on Edge', 'hybrid search on Edge', 'embeddings on device', 'Edge snapshots', 'apply a partial snapshot', 'why is my Edge search empty after inserts', or is writing custom sync, BM25, or fusion code against qdrant-edge. Also use when deciding what Edge ships built-in versus what you must implement."
---

# Building on Qdrant Edge

Edge is the Qdrant engine embedded in your process (Python or Rust), not a thin local vector store to wrap. The failure mode is rebuilding what the shard already ships: keyword scoring, snapshot apply, faceting, counting. Before writing any of that, check the shard API. Two things Edge does NOT give you are a one-call cloud sync and query-time fusion, so knowing which is which keeps you from both reinventing built-ins and expecting capabilities Edge lacks. Edge is single-node and shares the server's data format.

- Edge is in beta: pin your version, the API drifts between releases [Qdrant Edge](https://skills.qdrant.tech/md/documentation/edge/).


## Syncing a Shard with a Qdrant Server

Use when: seeding a shard from a server, keeping it fresh, backing it up, or aggregating many devices into one collection.

There is no built-in `.sync()`. Sync is a pattern you assemble from shard helpers plus your own transport, so do not go looking for one call.

- Follow the documented dual-shard pattern: a `mutable` shard for local writes plus an `immutable` shard restored from a server snapshot, query both, refresh on a schedule [Edge synchronization guide](https://skills.qdrant.tech/md/documentation/edge/edge-synchronization-guide/).
- You write the snapshot download (plain HTTP to the shard snapshot endpoint), then apply it with `unpack_snapshot` and `update_from_snapshot`. Do not untar or merge segments by hand [Synchronization patterns](https://skills.qdrant.tech/md/documentation/edge/edge-data-synchronization-patterns/).
- Refresh incrementally with a partial snapshot built from `snapshot_manifest`, not a full snapshot every cycle [Synchronization patterns](https://skills.qdrant.tech/md/documentation/edge/edge-data-synchronization-patterns/).
- Push is your own dual-write: on each local upsert, enqueue the point and let a background worker upsert it to the server, buffering while offline [Synchronization patterns](https://skills.qdrant.tech/md/documentation/edge/edge-data-synchronization-patterns/).


## Keyword and Hybrid Search on Device

Use when: you need exact-term or BM25 matching, alone or alongside vectors.

- BM25 is built into Edge (`Bm25`, `Bm25Config`, `embed_document`, `embed_query`) with the IDF `Modifier` on `EdgeSparseVectorParams`, and is wire-compatible with server BM25: a shard seeded from a server snapshot answers local BM25 queries without re-indexing. Do not ship a second BM25 library [Edge BM25](https://skills.qdrant.tech/md/documentation/edge/edge-bm25/)
- Dense embeddings are NOT in Edge: generate them on device with the separate `fastembed` package [FastEmbed embeddings](https://skills.qdrant.tech/md/documentation/edge/edge-fastembed-embeddings/)
- Edge queries one vector field per request (`using`) and does not fuse dense and sparse at query time. Run each leg separately and combine the rankings in application code [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)


## Operating the Shard

Use when: writes have accumulated, search looks stale after inserts, or a backup is larger than the data.

- Edge has NO background optimizer. Call `optimize` after bulk writes: it builds indexes (including the sparse index) and reclaims deleted points. Skip it and that data stays unindexed [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)
- Faceting, counting, and enumeration are built in (`facet`, `count`, `scroll`); index the fields you filter or facet with `create_field_index` rather than aggregating in application code [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)
- The write-ahead log is pre-allocated to 32 MB and inflates apparent disk and backup size. Shrink it with `wal_options` (Rust), and do not treat raw file size as real usage [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)


## What NOT to Do

- Expect a bidirectional `.sync()` or a built-in push path: Edge gives you snapshot apply, you own the transport and the dual-write
- Untar or merge snapshot segments by hand instead of using `unpack_snapshot` and `update_from_snapshot`
- Ship a custom or third-party BM25 when Edge has one built in
- Use `embed_document` for queries or `embed_query` for documents: the weighting differs and results go wrong
- Assume Edge fuses dense and sparse or consumes Prefetch: combine the rankings in application code
- Assume a background optimizer like the server's: nothing is indexed or compacted until you call `optimize`
- Reach for Edge when you need distributed or multi-node search: it is single-node [Qdrant Edge](https://skills.qdrant.tech/md/documentation/edge/)
- Claim support for a language beyond Python and Rust, or an OS or accelerator the Edge docs do not state
