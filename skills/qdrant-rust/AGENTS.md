# Qdrant Rust Client

Uses gRPC (port 6334, not REST 6333) via the `qdrant-client` crate. All methods are async (tokio).

## Setup

```rust
use qdrant_client::Qdrant;
let client = Qdrant::from_url("http://localhost:6334").build()?;
// cloud: .api_key(std::env::var("QDRANT_API_KEY")).build()?
```

## Quick Reference

| Operation | Code |
|-----------|------|
| Create collection | `client.create_collection(CreateCollectionBuilder::new("col").vectors_config(VectorParamsBuilder::new(768, Distance::Cosine)))` |
| Upsert | `client.upsert_points(UpsertPointsBuilder::new("col", points))` |
| Query | `client.query(QueryPointsBuilder::new("col").query(vec![0.2, 0.1, 0.9]))` |
| Filter | `.filter(Filter::must([Condition::matches("field", "value".to_string())]))` |
| With payload | `.with_payload(true)` |
| Scroll | `client.scroll(ScrollPointsBuilder::new("col").limit(100))` |
| Delete | `client.delete_points(DeletePointsBuilder::new("col").points(vec![0.into()]))` |
| Payload index | `client.create_field_index(CreateFieldIndexCollectionBuilder::new("col", "field", FieldType::Keyword))` |

Payload from JSON: `json!({"k": "v"}).try_into().unwrap()`

| Recommend | `Query::new_recommend(RecommendInput { positive: vec![id.into()], negative: vec![], ..Default::default() })` |
| Set payload | `client.set_payload(SetPayloadPointsBuilder::new("col", payload).points_selector(vec![id.into()]))` |
| Delete payload keys | `client.delete_payload(DeletePayloadPointsBuilder::new("col", vec!["key".into()]).points_selector(...))` |
| Snapshot | `client.create_snapshot(CreateSnapshotRequestBuilder::new("col"))`, `client.list_snapshots("col")` |
| Alias | `client.create_alias("alias", "col")`, `client.delete_alias("alias")` |
| Update collection | `client.update_collection(UpdateCollectionBuilder::new("col").optimizers_config(...))` |

## Hybrid Search (RRF)

Use `add_prefetch` with dense + sparse queries, then `Query::new_fusion(Fusion::Rrf)`:

```rust
client.query(QueryPointsBuilder::new("col")
    .add_prefetch(PrefetchQueryBuilder::default().query(Query::new_nearest(dense_vec)).using("dense").limit(20u64))
    .add_prefetch(PrefetchQueryBuilder::default().query(Query::new_nearest(sparse_vec)).using("sparse").limit(20u64))
    .query(Query::new_fusion(Fusion::Rrf)).limit(10u64)
).await?;
```

## Named Vectors

Use `VectorParamsMap` for multiple vector spaces:

```rust
let mut vectors = VectorParamsMap::new();
vectors.insert("image", VectorParamsBuilder::new(512, Distance::Euclid));
vectors.insert("text", VectorParamsBuilder::new(768, Distance::Cosine));
client.create_collection(CreateCollectionBuilder::new("col").vectors_config(vectors)).await?;
```

## Gotchas

- gRPC only (port 6334). REST port 6333 won't work with this client.
- `client.query(QueryPointsBuilder)` not `search_points` (older API).
- Payload conversion: always `json!({...}).try_into().unwrap()`.
- Builder pattern everywhere. Don't construct structs directly.
- `.wait(true)` for read-after-write consistency. Default returns before indexing.
- Never one collection per user. Use `is_tenant=true` payload index + filter.
- Vector dims must match collection config on every upsert and query.
- Distance is immutable. Delete and recreate collection to change.
- All client methods are async. Requires tokio runtime.

For comprehensive builder API reference, see `references/builders.md`.
