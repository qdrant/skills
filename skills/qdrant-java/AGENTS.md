# Qdrant Java Client

Uses gRPC (port 6334) via `io.qdrant:client`. All methods return `ListenableFuture<T>` (call `.get()` to block). Protobuf types with builder pattern. Static import factory classes for usable code.

## Setup

```java
import static io.qdrant.client.PointIdFactory.id;
import static io.qdrant.client.ValueFactory.value;
import static io.qdrant.client.VectorsFactory.vectors;
import static io.qdrant.client.QueryFactory.nearest;
import static io.qdrant.client.ConditionFactory.*;

QdrantClient client = new QdrantClient(
    QdrantGrpcClient.newBuilder("localhost", 6334, false).build());
```

## Quick Reference

| Operation | Code |
|-----------|------|
| Create collection | `client.createCollectionAsync("col", VectorParams.newBuilder().setSize(768).setDistance(Distance.Cosine).build())` |
| Upsert | `client.upsertAsync("col", List.of(PointStruct.newBuilder().setId(id(1)).setVectors(vectors(...)).putAllPayload(Map.of("k", value("v"))).build()))` |
| Query | `client.queryAsync(QueryPoints.newBuilder().setCollectionName("col").setQuery(nearest(...)).setLimit(10).build())` |
| Filter | `.setFilter(Filter.newBuilder().addMust(matchKeyword("field", "value")).build())` |
| Hybrid (RRF) | `.addPrefetch(...)` with `.setQuery(fusion(Fusion.RRF))` |
| Named vector | `.setUsing("image")` on QueryPoints |
| Scroll | `client.scrollAsync(ScrollPoints.newBuilder()...build())` with `.getNextPageOffset()` |
| Delete | `client.deleteAsync("col", List.of(id(0), id(1)))` or pass Filter |
| Payload index | `client.createPayloadIndexAsync("col", "field", PayloadSchemaType.Keyword, null, null, null, null)` |
| Multi-tenant | keyword index with `setIsTenant(true)` + filter per query |
| Recommend | `setQuery(recommend(List.of(vectorInput(id(1))), List.of(vectorInput(id(3)))))` |
| Set payload | `client.setPayloadAsync("col", Map.of("k", value("v")), List.of(id(1)), null, null)` |
| Delete payload keys | `client.deletePayloadAsync("col", List.of("key"), List.of(id(1)), null, null)` |
| Snapshot | `client.createSnapshotAsync("col")`, `client.listSnapshotAsync("col")` |
| Alias | `client.createAliasAsync("alias", "col")`, `client.deleteAliasAsync("alias")` |
| Update collection | `client.updateCollectionAsync(UpdateCollection.newBuilder().setCollectionName("col").setOptimizersConfig(...).build())` |

## Gotchas

- gRPC only (port 6334). Not REST.
- Everything returns `ListenableFuture<T>`. Call `.get()` to block.
- Builder pattern everywhere. `Type.newBuilder()...build()`.
- Factory classes required. Without `import static` for `id()`, `value()`, `vectors()`, `nearest()`, `matchKeyword()`, code is unreadable.
- `vectors()` (plural) for PointStruct. `vector()` (singular) for named vector maps.
- Payload values need `value()` wrapper: `value("str")`, `value(42L)`, `value(true)`.
- `nearest()` overloads: `float...`, `List<Float>`, `long` (ID), `UUID`, `float[][]` (multi), `List<Float>, List<Integer>` (sparse).
- Sparse vector upsert is verbose: build Vectors > NamedVectors > Map manually.
- `searchAsync` is legacy. Use `queryAsync` with `nearest()`.
- Protobuf types use getters: `.getId()`, `.getScore()`, `.getPayloadMap()`.
- Channel lifecycle: pass `true` as second arg to auto-shutdown on client close.
- Never one collection per user. Use `setIsTenant(true)` payload index.
- Vector dims must match collection config on every upsert and query.
- Distance is immutable. Delete and recreate collection to change.
