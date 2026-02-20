---
name: qdrant-rust
description: "Best practices for the Qdrant Rust client (qdrant-client crate). Use when writing Rust code that uses qdrant-client. Covers client setup, query, filtering, upsert, and common gotchas."
allowed-tools: Read Grep Glob
license: Apache-2.0
metadata:
  author: qdrant
  version: "1.0"
---

# Qdrant Rust Client

You interact with Qdrant over gRPC using the `qdrant-client` crate.

## Setup

```bash
cargo add qdrant-client anyhow tonic tokio serde-json --features tokio/rt-multi-thread
```

```rust
use qdrant_client::Qdrant;

// Local
let client = Qdrant::from_url("http://localhost:6334").build()?;

// Cloud
let client = Qdrant::from_url("https://xyz.cloud.qdrant.io:6334")
    .api_key(std::env::var("QDRANT_API_KEY"))
    .build()?;
```

## Decision Table

| Want to... | Do |
|-----------|-----|
| Create a collection | `client.create_collection(CreateCollectionBuilder::new("col").vectors_config(VectorParamsBuilder::new(768, Distance::Cosine)))` |
| Upsert points | `client.upsert_points(UpsertPointsBuilder::new("col", vec![PointStruct::new(1, vec![0.1, 0.2, ...], json!({"key": "val"}).try_into().unwrap())]))` |
| Query by vector | `client.query(QueryPointsBuilder::new("col").query(vec![0.2, 0.1, 0.9]))` |
| Query with filter | Add `.filter(Filter::must([Condition::matches("field", "value".to_string())]))` |
| Query with payload | Add `.with_payload(true)` to `QueryPointsBuilder` |
| List collections | `client.list_collections()` |
| Get collection info | `client.collection_info("col")` |
| Scroll points | `client.scroll(ScrollPointsBuilder::new("col").limit(100))` |
| Delete points | `client.delete_points(DeletePointsBuilder::new("col").points(vec![0.into(), 1.into()]))` |
| Create payload index | `client.create_field_index(CreateFieldIndexCollectionBuilder::new("col", "field", FieldType::Keyword))` |
| Recommend | `client.query(QueryPointsBuilder::new("col").query(Query::new_recommend(RecommendInput { positive: vec![id.into()], negative: vec![], ... })))` |
| Discover | `client.query(QueryPointsBuilder::new("col").query(Query::new_discover(DiscoverInput { target, context, ... })))` |
| Set payload | `client.set_payload(SetPayloadPointsBuilder::new("col", json!({"k": "v"}).try_into().unwrap()).points_selector(vec![0.into()]))` |
| Delete payload keys | `client.delete_payload(DeletePayloadPointsBuilder::new("col", vec!["key".into()]).points_selector(vec![0.into()]))` |
| Clear payload | `client.clear_payload(ClearPayloadPointsBuilder::new("col").points_selector(vec![0.into()]))` |
| Create snapshot | `client.create_snapshot(CreateSnapshotRequestBuilder::new("col"))` |
| List snapshots | `client.list_snapshots("col")` |
| Full snapshot | `client.create_full_snapshot()` |
| Create alias | `client.create_alias("alias", "col")` |
| Delete alias | `client.delete_alias("alias")` |
| Update collection | `client.update_collection(UpdateCollectionBuilder::new("col").optimizers_config(OptimizersConfigDiffBuilder::new().indexing_threshold(20000)))` |

## Query with Filter

```rust
use qdrant_client::qdrant::{Condition, Filter, QueryPointsBuilder};

let results = client
    .query(
        QueryPointsBuilder::new("products")
            .query(vec![0.2, 0.1, 0.9, 0.7])
            .filter(Filter::must([Condition::matches(
                "category",
                "electronics".to_string(),
            )]))
            .with_payload(true)
            .limit(10),
    )
    .await?;
```

## Upsert with Payload

```rust
use qdrant_client::qdrant::{PointStruct, UpsertPointsBuilder};
use serde_json::json;

let points = vec![
    PointStruct::new(
        1,
        vec![0.1, 0.2, 0.3],
        json!({"city": "London", "population": 9_000_000})
            .try_into()
            .unwrap(),
    ),
];

client
    .upsert_points(UpsertPointsBuilder::new("col", points).wait(true))
    .await?;
```

## Hybrid Search (Dense + Sparse with RRF)

```rust
use qdrant_client::qdrant::{
    PrefetchQueryBuilder, Query, QueryPointsBuilder, Fusion,
};

let results = client
    .query(
        QueryPointsBuilder::new("collection")
            .add_prefetch(
                PrefetchQueryBuilder::default()
                    .query(Query::new_nearest(dense_vec))
                    .using("dense")
                    .limit(20u64),
            )
            .add_prefetch(
                PrefetchQueryBuilder::default()
                    .query(Query::new_nearest(sparse_vec))
                    .using("sparse")
                    .limit(20u64),
            )
            .query(Query::new_fusion(Fusion::Rrf))
            .limit(10u64),
    )
    .await?;
```

## Named Vectors

```rust
use qdrant_client::qdrant::{
    CreateCollectionBuilder, VectorParamsBuilder, VectorParamsMap, Distance,
};

let mut vectors = VectorParamsMap::new();
vectors.insert("image", VectorParamsBuilder::new(512, Distance::Euclid));
vectors.insert("text", VectorParamsBuilder::new(768, Distance::Cosine));

client
    .create_collection(CreateCollectionBuilder::new("col").vectors_config(vectors))
    .await?;
```

## Recommend (Find Similar)

```rust
use qdrant_client::qdrant::{Query, RecommendInput};

client.query(
    QueryPointsBuilder::new("products")
        .query(Query::new_recommend(RecommendInput {
            positive: vec![1.into(), 2.into()],
            negative: vec![3.into()],
            ..Default::default()
        }))
        .limit(10u64),
).await?;
```

## Payload Mutation

```rust
use qdrant_client::qdrant::{SetPayloadPointsBuilder, DeletePayloadPointsBuilder};

// Set payload (merge)
client.set_payload(
    SetPayloadPointsBuilder::new("col", json!({"status": "reviewed"}).try_into().unwrap())
        .points_selector(vec![1.into(), 2.into()])
        .wait(true),
).await?;

// Delete specific keys
client.delete_payload(
    DeletePayloadPointsBuilder::new("col", vec!["temp_field".into()])
        .points_selector(vec![1.into()]),
).await?;
```

## Collection Aliases

```rust
// Zero-downtime swap
client.delete_alias("production").await?;
client.create_alias("production", "products_v2").await?;
```

## Gotchas

- **gRPC only**: The Rust client uses gRPC (port 6334), not REST (6333). Make sure gRPC is enabled.
- **`query` not `search_points`**: Use `client.query(QueryPointsBuilder)` for searches. `search_points` is the older API.
- **Payload conversion**: Use `json!({...}).try_into().unwrap()` to convert `serde_json::Value` into `Payload`.
- **Builder pattern everywhere**: All operations use builders (`CreateCollectionBuilder`, `QueryPointsBuilder`, etc.). Don't try to construct structs directly.
- **`.wait(true)` for consistency**: Upsert/delete return before indexing by default. Add `.wait(true)` if you need to query immediately after.
- **Never one collection per user**: Use payload index with `is_tenant=true` and filter per query.
- **Vector size must match**: Every upsert and query must match the collection's configured dimensions.
- **Distance is immutable**: Delete and recreate the collection to change it.
- **Async only**: All client methods are async. You need a tokio runtime.

## Read More

- [qdrant-client on crates.io](https://crates.io/crates/qdrant-client)
- [API docs on docs.rs](https://docs.rs/qdrant-client)
- [Qdrant Documentation](https://qdrant.tech/documentation/)

## References

- `references/builders.md`: Comprehensive builder API reference
- `references/advanced-indexing.md`: HNSW tuning, quantization, ColBERT multi-vector config
