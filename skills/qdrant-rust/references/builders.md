# Builder API Reference

Comprehensive reference for the Qdrant Rust client builder types.

## Collection Builders

### CreateCollectionBuilder

```rust
use qdrant_client::qdrant::{
    CreateCollectionBuilder, Distance, VectorParamsBuilder,
};

// Single vector
CreateCollectionBuilder::new("collection")
    .vectors_config(VectorParamsBuilder::new(768, Distance::Cosine))

// Named vectors
use qdrant_client::qdrant::VectorParamsMap;

let mut vectors = VectorParamsMap::new();
vectors.insert("dense", VectorParamsBuilder::new(768, Distance::Cosine));
vectors.insert("sparse", /* sparse config */);

CreateCollectionBuilder::new("collection")
    .vectors_config(vectors)
```

### UpdateCollectionBuilder

```rust
use qdrant_client::qdrant::UpdateCollectionBuilder;

UpdateCollectionBuilder::new("collection")
    .optimizers_config(OptimizersConfigDiffBuilder::new()
        .indexing_threshold(20000))
```

## Point Builders

### UpsertPointsBuilder

```rust
use qdrant_client::qdrant::{PointStruct, UpsertPointsBuilder};
use serde_json::json;

let points = vec![
    PointStruct::new(
        1,                           // id: u64 or String
        vec![0.1, 0.2, 0.3],       // vector
        json!({"key": "value"})      // payload
            .try_into().unwrap(),
    ),
];

UpsertPointsBuilder::new("collection", points)
    .wait(true)          // wait for indexing
    .ordering(WriteOrdering {
        r#type: WriteOrderingType::Strong as i32,
    })
```

### PointStruct constructors

```rust
// With u64 ID
PointStruct::new(1, vec![0.1, 0.2], json!({}).try_into().unwrap())

// With string ID
PointStruct::new("point-uuid", vec![0.1, 0.2], json!({}).try_into().unwrap())

// Named vectors
use std::collections::HashMap;
let mut vectors = HashMap::new();
vectors.insert("dense".to_string(), vec![0.1, 0.2, 0.3]);

PointStruct::new(1, vectors, json!({"key": "val"}).try_into().unwrap())
```

## Query Builders

### QueryPointsBuilder

```rust
use qdrant_client::qdrant::QueryPointsBuilder;

QueryPointsBuilder::new("collection")
    .query(vec![0.2, 0.1, 0.9])    // vector query
    .filter(filter)                  // optional filter
    .with_payload(true)              // return payload
    .with_vectors(true)              // return vectors
    .limit(10)                       // max results
    .offset(0)                       // skip N results
    .score_threshold(0.5)            // min score
    .using("dense")                  // named vector
```

### ScrollPointsBuilder

```rust
use qdrant_client::qdrant::ScrollPointsBuilder;

ScrollPointsBuilder::new("collection")
    .filter(filter)
    .limit(100)
    .offset(PointId::from(0))       // cursor-based
    .with_payload(true)
    .with_vectors(true)
    .order_by(OrderByBuilder::new("timestamp"))
```

### RecommendPointsBuilder

```rust
use qdrant_client::qdrant::RecommendPointsBuilder;

RecommendPointsBuilder::new("collection")
    .add_positive(PointId::from(1))
    .add_positive(PointId::from(2))
    .add_negative(PointId::from(3))
    .limit(10)
    .filter(filter)
    .with_payload(true)
```

## Filter Builders

### Filter

```rust
use qdrant_client::qdrant::{Condition, Filter};

// Must (AND)
Filter::must([
    Condition::matches("field", "value".to_string()),
])

// Should (OR)
Filter::should([
    Condition::matches("color", "red".to_string()),
    Condition::matches("color", "blue".to_string()),
])

// Must not (NOT)
Filter::must_not([
    Condition::matches("deleted", true),
])

// Combined
Filter {
    must: vec![Condition::matches("type", "doc".to_string()).into()],
    should: vec![],
    must_not: vec![Condition::matches("archived", true).into()],
    min_should: None,
}
```

### Condition types

```rust
// Exact match
Condition::matches("field", "value".to_string())
Condition::matches("field", 42_i64)
Condition::matches("field", true)

// Range
use qdrant_client::qdrant::Range;
Condition::range("price", Range {
    gte: Some(10.0),
    lte: Some(100.0),
    ..Default::default()
})

// Has ID
Condition::has_id([1, 2, 3])

// Is null
Condition::is_null("field")

// Is empty
Condition::is_empty("tags")

// Nested
Condition::nested("reviews", Filter::must([
    Condition::range("reviews[].score", Range {
        gte: Some(4.0),
        ..Default::default()
    }),
]))

// Geo bounding box
use qdrant_client::qdrant::{GeoBoundingBox, GeoPoint};
Condition::geo_bounding_box("location", GeoBoundingBox {
    top_left: Some(GeoPoint { lat: 52.52, lon: 13.35 }),
    bottom_right: Some(GeoPoint { lat: 52.50, lon: 13.45 }),
})

// Geo radius
use qdrant_client::qdrant::GeoRadius;
Condition::geo_radius("location", GeoRadius {
    center: Some(GeoPoint { lat: 52.52, lon: 13.405 }),
    radius: 1000.0,
})
```

## Delete Builders

### DeletePointsBuilder

```rust
use qdrant_client::qdrant::DeletePointsBuilder;

// By IDs
DeletePointsBuilder::new("collection")
    .points(vec![0.into(), 1.into()])
    .wait(true)

// By filter
DeletePointsBuilder::new("collection")
    .points(Filter::must([
        Condition::matches("status", "expired".to_string()),
    ]))
    .wait(true)
```

## Index Builders

### CreateFieldIndexCollectionBuilder

```rust
use qdrant_client::qdrant::{CreateFieldIndexCollectionBuilder, FieldType};

// Keyword index
CreateFieldIndexCollectionBuilder::new("collection", "category", FieldType::Keyword)

// Integer index
CreateFieldIndexCollectionBuilder::new("collection", "count", FieldType::Integer)

// Float index
CreateFieldIndexCollectionBuilder::new("collection", "price", FieldType::Float)

// Geo index
CreateFieldIndexCollectionBuilder::new("collection", "location", FieldType::Geo)

// Datetime index
CreateFieldIndexCollectionBuilder::new("collection", "created_at", FieldType::Datetime)

// Text (full-text) index
CreateFieldIndexCollectionBuilder::new("collection", "description", FieldType::Text)

// Tenant index
CreateFieldIndexCollectionBuilder::new("collection", "tenant_id", FieldType::Keyword)
    .is_tenant(true)
```

## Snapshot Builders

### CreateSnapshotBuilder

```rust
use qdrant_client::qdrant::CreateSnapshotRequestBuilder;

// Collection snapshot
client.create_snapshot(CreateSnapshotRequestBuilder::new("collection")).await?;

// Full storage snapshot
client.create_full_snapshot().await?;
```
