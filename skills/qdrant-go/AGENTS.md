# Qdrant Go Client

Uses gRPC only (port 6334) via `github.com/qdrant/go-client/qdrant`. All types are protobuf structs. Pointer-heavy API, use `qdrant.PtrOf(value)` everywhere.

## Setup

```go
import "github.com/qdrant/go-client/qdrant"
client, err := qdrant.NewClient(&qdrant.Config{Host: "localhost", Port: 6334})
// cloud: add APIKey, UseTLS: true
```

## Quick Reference

| Operation | Code |
|-----------|------|
| Create collection | `client.CreateCollection(ctx, &qdrant.CreateCollection{CollectionName: "col", VectorsConfig: qdrant.NewVectorsConfig(&qdrant.VectorParams{Size: 768, Distance: qdrant.Distance_Cosine})})` |
| Upsert | `client.Upsert(ctx, &qdrant.UpsertPoints{CollectionName: "col", Points: points, Wait: qdrant.PtrOf(true)})` |
| Query | `client.Query(ctx, &qdrant.QueryPoints{CollectionName: "col", Query: qdrant.NewQuery(0.2, 0.1, 0.9)})` |
| Filter | `Filter: &qdrant.Filter{Must: []*qdrant.Condition{qdrant.NewMatch("field", "value")}}` |
| Hybrid (RRF) | `Prefetch` with dense+sparse, `Query: qdrant.NewQueryFusion(qdrant.Fusion_RRF)` |
| Scroll | `client.Scroll(ctx, req)` or `client.ScrollAndOffset(ctx, req)` for pagination |
| Delete | `client.Delete(ctx, &qdrant.DeletePoints{CollectionName: "col", Points: qdrant.NewPointsSelector(ids...)})` |
| Payload index | `client.CreateFieldIndex(ctx, &qdrant.CreateFieldIndexCollection{...FieldType: qdrant.FieldType_FieldTypeKeyword.Enum()})` |
| Multi-tenant | keyword index with `IsTenant: qdrant.PtrOf(true)` + filter per query |
| Recommend | `Query: qdrant.NewQueryRecommend(&qdrant.RecommendInput{Positive: [...], Negative: [...]})` |
| Set payload | `client.SetPayload(ctx, &qdrant.SetPayloadPoints{Payload: qdrant.NewValueMap(m), PointsSelector: ...})` |
| Delete payload keys | `client.DeletePayload(ctx, &qdrant.DeletePayloadPoints{Keys: []string{"k"}, PointsSelector: ...})` |
| Snapshot | `client.CreateSnapshot(ctx, "col")`, `client.ListSnapshots(ctx, "col")` |
| Alias | `client.CreateAlias(ctx, "alias", "col")`, `client.DeleteAlias(ctx, "alias")` |
| Update collection | `client.UpdateCollection(ctx, &qdrant.UpdateCollection{CollectionName: "col", OptimizersConfig: ...})` |

## Gotchas

- gRPC only (port 6334). Port 6333 won't work.
- Pointer-heavy. `qdrant.PtrOf(value)` for all optional fields. Watch types: scroll Limit is `*uint32`, query Limit is `*uint64`.
- `NewValueMap` panics on bad types. Use `TryValueMap` for error handling.
- No `Search` method. Only `Query`/`QueryBatch`/`QueryGroups`.
- `Scroll` discards offset. Use `ScrollAndOffset` for cursor-based pagination.
- Enum syntax: `qdrant.Distance_Cosine`. Field types need `.Enum()` call.
- `Using` is `*string`: `qdrant.PtrOf("image")` for named vector queries.
- Datetime ranges need `timestamppb.New(time.Date(...))`, not `time.Time`.
- Connection pool default is 3 connections with round-robin.
- `CollectionName` required in each inner query of batch operations.
- Never one collection per user. Use `IsTenant: true` payload index.
- Vector dims must match collection config on every upsert and query.
- Distance is immutable. Delete and recreate collection to change.
