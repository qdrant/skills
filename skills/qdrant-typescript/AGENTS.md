# Qdrant TypeScript/JavaScript SDK

Use `@qdrant/js-client-rest` (REST, port 6333). Filters are plain JS objects, no model imports needed.

## Quick Reference

| Operation | Code |
|-----------|------|
| Create collection | `client.createCollection('col', { vectors: { size: N, distance: 'Cosine' } })` |
| Upsert | `client.upsert('col', { points: [{ id: 1, vector: [...], payload: {...} }] })` |
| Query (preferred) | `client.query('col', { query: vector, limit: 10 })` |
| Filter query | add `filter: { must: [{ key: k, match: { value: v } }] }` |
| Hybrid (RRF) | `prefetch: [{ query: dense, using: 'dense', limit: 20 }, { query: sparse, using: 'sparse', limit: 20 }]`, `query: { fusion: 'rrf' }` |
| MMR | `query: { nearest: vec, mmr: { diversity: 0.5 } }` |
| Scroll | `client.scroll('col', { limit: 100 })` returns `{ points, next_page_offset }` |
| Payload index | `client.createPayloadIndex('col', { field_name: 'f', field_schema: 'keyword' })` |
| Multi-tenant | `field_schema: { type: 'keyword', is_tenant: true }` + filter per query |
| Named vectors | `vectors: { image: { size: 4, distance: 'Dot' } }`, query with `using: 'image'` |
| Recommend | `query: { recommend: { positive: [id1], negative: [id2] } }` |
| Discover | `query: { discover: { target: id, context: [{ positive: p, negative: n }] } }` |
| Set payload | `client.setPayload('col', { payload: {...}, points: [id] })` |
| Delete payload keys | `client.deletePayload('col', { keys: ['k'], points: [id] })` |
| Snapshot | `client.createSnapshot('col')`, `client.listSnapshots('col')` |
| Alias (swap) | `client.updateCollectionAliases({ actions: [{ delete_alias: ... }, { create_alias: ... }] })` |
| Update collection | `client.updateCollection('col', { optimizers_config: { indexing_threshold: 20000 } })` |

## Gotchas

- `query()` not `query_points()`. Method name differs from Python.
- `search()` still exists but `query()` is the modern API. Prefer `query()`.
- No model classes. Filters are plain objects: `{ must: [{ key: k, match: { value: v } }] }`.
- No `upload_points`. Only `upsert()`. Batch manually for bulk.
- Distance values are strings: `'Cosine'`, `'Euclid'`, `'Dot'`, `'Manhattan'`.
- REST client (port 6333), not gRPC. Separate `@qdrant/js-client-grpc` exists.
- `upsert` defaults `wait: true`. Writes block until indexed.
- Scroll returns object `{ points, next_page_offset }`, not a tuple.
- `prefetch` accepts object (pipeline) or array (fusion). Array for hybrid search.
- Constructor rejects both `url` and `host` together. Pick one.
- Never one collection per user. Use `is_tenant: true` payload index.
- Vector dims must match collection config on every upsert and query.
- Distance is immutable. Delete and recreate collection to change.
