# Qdrant Python SDK

Use `qdrant-client`. All search goes through `query_points` (not `search`, which is removed).

## Quick Reference

| Operation | Code |
|-----------|------|
| Create collection | `client.create_collection(name, vectors_config=VectorParams(size=N, distance=Distance.COSINE))` |
| Upsert | `client.upsert(col, points=[PointStruct(id, vector, payload)])` |
| Bulk upsert | `client.upload_points(col, points, batch_size=1000)` |
| Search | `client.query_points(col, query=vector, limit=10)` |
| Filter search | add `query_filter=Filter(must=[FieldCondition(key=k, match=MatchValue(value=v))])` |
| Hybrid (RRF) | `prefetch=[Prefetch(query=dense, using="dense", limit=20), Prefetch(query=sparse, using="sparse", limit=20)]`, `query=FusionQuery(fusion=Fusion.RRF)` |
| MMR | `query=NearestQuery(nearest=emb, mmr=Mmr(diversity=0.5))` |
| Scroll | `client.scroll(col, limit=100)` returns `(points, next_offset)` |
| Payload index | `client.create_payload_index(col, field, schema_type=PayloadSchemaType.KEYWORD)` |
| Multi-tenant | one collection + `create_payload_index(field, is_tenant=True)` + filter per query |
| Cloud inference | init with `cloud_inference=True`, query with `Document(text="q", model="model-name")` |
| Recommend | `query=RecommendQuery(positive=[id1], negative=[id2])` |
| Discover | `query=DiscoverQuery(target=id, context=[ContextPair(positive=p, negative=n)])` |
| Set payload | `client.set_payload(col, payload={"k": "v"}, points=[id])` |
| Delete payload keys | `client.delete_payload(col, keys=["k"], points=[id])` |
| Snapshot | `client.create_snapshot(col)`, `client.list_snapshots(col)`, `client.download_snapshot(col, name, path)` |
| Alias (swap) | `client.update_collection_aliases(change_aliases_operations=[DeleteAliasOp, CreateAliasOp])` |
| Update collection | `client.update_collection(col, optimizer_config=OptimizersConfigDiff(...))` |

## Gotchas

- `query_points` not `search`. All search variants removed.
- Never one collection per user. Use `is_tenant=True` payload index.
- Create payload indexes BEFORE bulk upload (avoids full re-index).
- BM25 needs `Modifier.IDF` or sparse quality is poor.
- Prefetch limit must be > final limit (it's the candidate pool).
- Scroll offset is a cursor (point ID), not a skip count.
- Don't exact-match floats. Use `Range(gte=19.98, lte=20.0)`.
- Distance is immutable. Delete and recreate collection to change.
- Vector dims must match collection config on every insert and query.
- Use `upload_points` for bulk. Don't loop `upsert` for 10k+ points.
- `acorn=True` only helps with filters. Adds overhead without them.
- Cloud inference requires `cloud_inference=True` on client init.

References: `filtering.md` (filter syntax), `migration-guide.md` (old API to new), `common-errors.md` (runtime errors), `data-ingestion.md` (bulk upload patterns), `fastembed.md` (local embeddings), `advanced-indexing.md` (HNSW, quantization, ColBERT).
