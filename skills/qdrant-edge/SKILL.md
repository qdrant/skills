---
name: qdrant-edge
description: "Guides building on Qdrant Edge, the embedded in-process shard. Use when someone asks 'how to sync Edge with the server', 'keep a local shard in sync with Qdrant Cloud', 'BM25 or keyword search on Edge', 'hybrid search on Edge', 'embeddings on device', 'Edge snapshots', 'apply a partial snapshot', or is writing custom sync, BM25, or fusion code against qdrant-edge. Also use when deciding what Edge ships built-in versus what you must implement."
---

# Building on Qdrant Edge

Edge is the Qdrant engine embedded in your process (Python or Rust), not a thin local vector store to wrap. The failure mode is rebuilding what the shard already ships: keyword scoring, snapshot handling, faceting. Before writing any of that, check the shard API. Two things Edge genuinely does NOT give you are a one-call cloud sync and query-time fusion, so knowing which is which keeps you from both reinventing built-ins and expecting capabilities Edge lacks. Edge is single-node and shares the server's data format.

- Start from what a shard is and does [Qdrant Edge](https://skills.qdrant.tech/md/documentation/edge/)


## Syncing a Shard With a Qdrant Server

Use when: keeping a local Edge shard in step with a Qdrant Cloud or server collection.

There is no built-in `.sync()`. Sync is a pattern you implement, not one call, so do not invent a protocol or hand-parse snapshot tarballs.

- Follow the documented dual-shard pattern: a `mutable` shard for this device's writes plus an `immutable` shard loaded from a server snapshot, query both, refresh the immutable one on a schedule [Edge synchronization guide](https://skills.qdrant.tech/md/documentation/edge/edge-synchronization-guide/)
- Apply snapshots with the shard helpers (`snapshot_manifest`, `unpack_snapshot`, `update_from_snapshot`), never custom tar extraction [Synchronization patterns](https://skills.qdrant.tech/md/documentation/edge/edge-data-synchronization-patterns/)
- Push is your own upserts to the server: the helpers cover the pull side only. Buffer writes while offline and drain the queue on reconnect [Edge synchronization guide](https://skills.qdrant.tech/md/documentation/edge/edge-synchronization-guide/)
- Seed a fresh shard straight from a snapshot: seeding and refresh share one apply path [Synchronization patterns](https://skills.qdrant.tech/md/documentation/edge/edge-data-synchronization-patterns/)


## Keyword and Hybrid Search on Device

Use when: you need exact-term or BM25 matching, alone or alongside vectors.

- BM25 is built into Edge (`Bm25`, `Bm25Config`, `embed_document`, `embed_query`), with the IDF `Modifier` on `EdgeSparseVectorParams`. Do not reimplement term scoring or ship a second BM25 library [Edge BM25](https://skills.qdrant.tech/md/documentation/edge/edge-bm25/)
- Dense embeddings are NOT in Edge: generate them on device with the separate `fastembed` package [FastEmbed embeddings](https://skills.qdrant.tech/md/documentation/edge/edge-fastembed-embeddings/)
- Fusion (RRF, DBSF) is NOT consumed by Edge's query path: run the dense and sparse legs separately and combine them in application code. This is the one place hand-rolling is correct, not a smell [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)


## Reaching for a Server-Side Feature

Use when: you are about to aggregate, count, or index in application code.

- Faceting is built in (`facet` with a `FacetRequest`), so do not scroll and tally in Python [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)
- Create payload field indexes at setup (`create_field_index`) so filtered queries stay fast [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)
- Reclaim space and keep segments healthy with `optimize` and `EdgeOptimizersConfig`, not manual compaction [Edge quickstart](https://skills.qdrant.tech/md/documentation/edge/edge-quickstart/)


## What NOT to Do

- Hand-roll snapshot download and tar handling instead of the shard's snapshot helpers
- Expect a bidirectional `.sync()` or a built-in push path: Edge gives you snapshot apply, you own the upload
- Ship a custom or third-party BM25 when Edge has one built in
- Assume Edge consumes Prefetch or Fusion: combine dense and sparse results in application code until the docs state otherwise
- Reach for Edge when you need distributed or multi-node search: it is single-node [Qdrant Edge](https://skills.qdrant.tech/md/documentation/edge/)
- Claim support for a language beyond Python and Rust, or an OS or accelerator the Edge docs do not state
