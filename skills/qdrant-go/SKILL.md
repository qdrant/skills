---
name: qdrant-go
description: "Best practices for the Qdrant Go client (github.com/qdrant/go-client). Use when writing Go code that uses qdrant. Covers client setup, query, filtering, hybrid search, and common gotchas."
allowed-tools: Read Grep Glob
license: Apache-2.0
metadata:
  author: qdrant
  version: "1.0"
---

# Qdrant Go Client

You interact with Qdrant over gRPC using `github.com/qdrant/go-client/qdrant`. All types are protobuf-generated structs. The client is gRPC-only (port 6334).

## Setup

```bash
go get -u github.com/qdrant/go-client
```

```go
import "github.com/qdrant/go-client/qdrant"

// Local
client, err := qdrant.NewClient(&qdrant.Config{
    Host: "localhost",
    Port: 6334,
})
defer client.Close()

// Cloud
client, err := qdrant.NewClient(&qdrant.Config{
    Host:   "xyz.cloud.qdrant.io",
    Port:   6334,
    APIKey: os.Getenv("QDRANT_API_KEY"),
    UseTLS: true,
})
```

## Decision Table

| Want to... | Do |
|-----------|-----|
| Create collection | `client.CreateCollection(ctx, &qdrant.CreateCollection{CollectionName: "col", VectorsConfig: qdrant.NewVectorsConfig(&qdrant.VectorParams{Size: 768, Distance: qdrant.Distance_Cosine})})` |
| Upsert | `client.Upsert(ctx, &qdrant.UpsertPoints{CollectionName: "col", Points: points})` |
| Query | `client.Query(ctx, &qdrant.QueryPoints{CollectionName: "col", Query: qdrant.NewQuery(0.2, 0.1, 0.9)})` |
| Filter | `Filter: &qdrant.Filter{Must: []*qdrant.Condition{qdrant.NewMatch("field", "value")}}` |
| Hybrid (RRF) | Use `Prefetch` with dense + sparse, `Query: qdrant.NewQueryFusion(qdrant.Fusion_RRF)` |
| Scroll | `client.Scroll(ctx, &qdrant.ScrollPoints{CollectionName: "col", Limit: qdrant.PtrOf(uint32(100))})` |
| Scroll with offset | `client.ScrollAndOffset(ctx, req)` returns `(points, *PointId, error)` |
| Delete by IDs | `client.Delete(ctx, &qdrant.DeletePoints{CollectionName: "col", Points: qdrant.NewPointsSelector(ids...)})` |
| Delete by filter | `client.Delete(ctx, &qdrant.DeletePoints{CollectionName: "col", Points: qdrant.NewPointsSelectorFilter(filter)})` |
| Payload index | `client.CreateFieldIndex(ctx, &qdrant.CreateFieldIndexCollection{CollectionName: "col", FieldName: "f", FieldType: qdrant.FieldType_FieldTypeKeyword.Enum()})` |
| Multi-tenant | Keyword index with `IsTenant: qdrant.PtrOf(true)` + filter per query |
| Recommend | `Query: qdrant.NewQueryRecommend(&qdrant.RecommendInput{Positive: [...], Negative: [...]})` |
| Discover | `Query: qdrant.NewQueryDiscover(&qdrant.DiscoverInput{Target: ..., Context: ...})` |
| Set payload | `client.SetPayload(ctx, &qdrant.SetPayloadPoints{CollectionName: "col", Payload: map, PointsSelector: ...})` |
| Delete payload keys | `client.DeletePayload(ctx, &qdrant.DeletePayloadPoints{CollectionName: "col", Keys: []string{"k"}, PointsSelector: ...})` |
| Clear payload | `client.ClearPayload(ctx, &qdrant.ClearPayloadPoints{CollectionName: "col", Points: ...})` |
| Create snapshot | `client.CreateSnapshot(ctx, "col")` |
| List snapshots | `client.ListSnapshots(ctx, "col")` |
| Create alias | `client.CreateAlias(ctx, "alias", "col")` |
| Delete alias | `client.DeleteAlias(ctx, "alias")` |
| Update collection | `client.UpdateCollection(ctx, &qdrant.UpdateCollection{CollectionName: "col", OptimizersConfig: ...})` |

## Query with Filter

```go
results, err := client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "products",
    Query:          qdrant.NewQuery(0.2, 0.1, 0.9, 0.7),
    Filter: &qdrant.Filter{
        Must: []*qdrant.Condition{
            qdrant.NewMatch("category", "electronics"),
        },
    },
    WithPayload: qdrant.NewWithPayload(true),
    Limit:       qdrant.PtrOf(uint64(10)),
})
```

## Upsert with Payload

```go
wait := true
_, err := client.Upsert(ctx, &qdrant.UpsertPoints{
    CollectionName: "col",
    Wait:           &wait,
    Points: []*qdrant.PointStruct{
        {
            Id:      qdrant.NewIDNum(1),
            Vectors: qdrant.NewVectors(0.05, 0.61, 0.76, 0.74),
            Payload: qdrant.NewValueMap(map[string]any{
                "city": "Berlin", "population": 3_500_000,
            }),
        },
    },
})
```

## Hybrid Search (Dense + Sparse with RRF)

```go
results, err := client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "col",
    Prefetch: []*qdrant.PrefetchQuery{
        {
            Query: qdrant.NewQuerySparse([]uint32{1, 42}, []float32{0.22, 0.8}),
            Using: qdrant.PtrOf("sparse"),
            Limit: qdrant.PtrOf(uint64(20)),
        },
        {
            Query: qdrant.NewQueryDense([]float32{0.01, 0.45, 0.67}),
            Using: qdrant.PtrOf("dense"),
            Limit: qdrant.PtrOf(uint64(20)),
        },
    },
    Query: qdrant.NewQueryFusion(qdrant.Fusion_RRF),
})
```

## Named Vectors

```go
// Create
client.CreateCollection(ctx, &qdrant.CreateCollection{
    CollectionName: "col",
    VectorsConfig: qdrant.NewVectorsConfigMap(map[string]*qdrant.VectorParams{
        "image": {Size: 4, Distance: qdrant.Distance_Dot},
        "text":  {Size: 8, Distance: qdrant.Distance_Cosine},
    }),
})

// Upsert
client.Upsert(ctx, &qdrant.UpsertPoints{
    CollectionName: "col",
    Points: []*qdrant.PointStruct{{
        Id: qdrant.NewIDNum(1),
        Vectors: qdrant.NewVectorsMap(map[string]*qdrant.Vector{
            "image": qdrant.NewVector(0.9, 0.1, 0.1, 0.2),
            "text":  qdrant.NewVector(0.4, 0.7, 0.1, 0.8),
        }),
    }},
})

// Query specific vector
client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "col",
    Query:          qdrant.NewQuery(0.9, 0.1, 0.1, 0.2),
    Using:          qdrant.PtrOf("image"),
})
```

## Key Constructor Helpers

| Helper | Creates |
|--------|---------|
| `qdrant.NewIDNum(42)` / `qdrant.NewID("uuid")` | Point IDs |
| `qdrant.NewVectors(0.1, 0.2)` / `qdrant.NewVectorsDense(slice)` | Dense vectors |
| `qdrant.NewVectorsSparse(indices, values)` | Sparse vector |
| `qdrant.NewVectorsMap(map)` | Named vectors |
| `qdrant.NewQuery(0.1, 0.2)` / `qdrant.NewQueryDense(slice)` | Query nearest |
| `qdrant.NewQueryFusion(qdrant.Fusion_RRF)` | Fusion query |
| `qdrant.NewQueryRecommend(input)` | Recommend query |
| `qdrant.NewMatch("field", "value")` | Match condition |
| `qdrant.NewRange("field", range)` | Range condition |
| `qdrant.NewValueMap(map[string]any{...})` | Payload (panics on bad types) |
| `qdrant.PtrOf(value)` | Pointer to any value |
| `qdrant.NewWithPayload(true)` | Payload selector |
| `qdrant.NewPointsSelector(ids...)` | Points selector by IDs |

## Filtering

```go
// Match
qdrant.NewMatch("city", "Berlin")            // keyword
qdrant.NewMatchInt("count", 42)              // integer
qdrant.NewMatchBool("active", true)          // boolean
qdrant.NewMatchKeywords("color", "r", "g")   // any-of
qdrant.NewMatchExceptKeywords("x", "a", "b") // none-of

// Range
qdrant.NewRange("price", &qdrant.Range{Gte: qdrant.PtrOf(10.0), Lte: qdrant.PtrOf(100.0)})

// Datetime (uses timestamppb)
qdrant.NewDatetimeRange("date", &qdrant.DatetimeRange{
    Gte: timestamppb.New(startTime),
    Lt:  timestamppb.New(endTime),
})

// Geo
qdrant.NewGeoRadius("location", 52.52, 13.40, 1000.0)

// Existence
qdrant.NewIsNull("field")
qdrant.NewIsEmpty("tags")
qdrant.NewHasID(qdrant.NewIDNum(1), qdrant.NewIDNum(2))

// Nested
qdrant.NewNestedFilter("reviews", &qdrant.Filter{
    Must: []*qdrant.Condition{qdrant.NewRange("reviews[].score", ...)},
})
```

## Recommend (Find Similar)

```go
results, err := client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "products",
    Query: qdrant.NewQueryRecommend(&qdrant.RecommendInput{
        Positive: []*qdrant.VectorInput{
            {Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(1)}},
            {Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(2)}},
        },
        Negative: []*qdrant.VectorInput{
            {Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(3)}},
        },
    }),
    Limit: qdrant.PtrOf(uint64(10)),
})
```

## Payload Mutation

```go
// Set payload (merge)
client.SetPayload(ctx, &qdrant.SetPayloadPoints{
    CollectionName: "col",
    Payload:        qdrant.NewValueMap(map[string]any{"status": "reviewed"}),
    PointsSelector: qdrant.NewPointsSelector(qdrant.NewIDNum(1)),
    Wait:           qdrant.PtrOf(true),
})

// Delete specific keys
client.DeletePayload(ctx, &qdrant.DeletePayloadPoints{
    CollectionName: "col",
    Keys:           []string{"temp_field"},
    PointsSelector: qdrant.NewPointsSelector(qdrant.NewIDNum(1)),
})
```

## Collection Aliases

```go
// Zero-downtime swap
client.DeleteAlias(ctx, "production")
client.CreateAlias(ctx, "production", "products_v2")
```

## Gotchas

- **gRPC only, port 6334**: No REST fallback. Port 6333 does not work with this client.
- **Pointer-heavy API**: Optional fields are pointers. Use `qdrant.PtrOf(value)` constantly. Watch types: `Limit` on scroll is `*uint32`, on query is `*uint64`.
- **`NewValueMap` panics on bad types**: Use `TryValueMap` for error-returning version if input is untrusted.
- **No `Search` method**: Only `Query`/`QueryBatch`/`QueryGroups`. Everything goes through the unified query API.
- **`Scroll` vs `ScrollAndOffset`**: `Scroll` discards the next offset. Use `ScrollAndOffset` for pagination.
- **Enum syntax**: `qdrant.Distance_Cosine`, not `qdrant.Cosine`. Field types need `.Enum()`: `qdrant.FieldType_FieldTypeKeyword.Enum()`.
- **`Using` is `*string`**: Named vector queries need `Using: qdrant.PtrOf("image")`, not a bare string.
- **Datetime uses protobuf Timestamp**: `timestamppb.New(time.Date(...))`, not `time.Time` directly.
- **Connection pool default is 3**: Not 1. Round-robin across connections.
- **`CollectionName` required in batch inner queries**: Each `QueryPoints` in `QueryBatchPoints` must set its own `CollectionName`.
- **Never one collection per user**: Use payload index with `IsTenant: true`.
- **Vector size must match**: Every upsert and query must match collection dims.
- **Distance is immutable**: Delete and recreate collection to change it.

## Read More

- [GitHub: qdrant/go-client](https://github.com/qdrant/go-client)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
