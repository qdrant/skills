# Qdrant .NET/C# Client

Uses gRPC (port 6334) via `Qdrant.Client` NuGet. All methods are async (`*Async`). Filtering uses `&`/`|`/`!` operator overloads on conditions.

## Setup

```csharp
using Qdrant.Client;
using Qdrant.Client.Grpc;
using static Qdrant.Client.Grpc.Conditions;
var client = new QdrantClient("localhost");
// cloud: new QdrantClient("xyz.cloud.qdrant.io", port: 6334, https: true, apiKey: "...")
```

## Quick Reference

| Operation | Code |
|-----------|------|
| Create collection | `client.CreateCollectionAsync("col", new VectorParams { Size = 768, Distance = Distance.Cosine })` |
| Upsert | `client.UpsertAsync("col", points)` (IReadOnlyList\<PointStruct\>) |
| Query | `client.QueryAsync("col", query: new float[] { ... }, limit: 10)` |
| Filter query | `filter: MatchKeyword("field", "value")` (single Condition converts to Filter) |
| Hybrid (RRF) | `query: Fusion.Rrf, prefetch: new List<PrefetchQuery> { ... }` |
| Scroll | `client.ScrollAsync("col", limit: 100)` returns `ScrollResponse` (.Result, .NextPageOffset) |
| Delete | `client.DeleteAsync("col", ids)` or `client.DeleteAsync("col", filter)` |
| Payload index | `client.CreatePayloadIndexAsync("col", "field", PayloadSchemaType.Keyword)` |
| Multi-tenant | keyword index + filter per query |
| Recommend | `query: new RecommendInput { Positive = { id.ToVectorInput() }, Negative = { ... } }` |
| Set payload | `client.SetPayloadAsync("col", payload, ids)` |
| Delete payload keys | `client.DeletePayloadAsync("col", keys, ids)` |
| Snapshot | `client.CreateSnapshotAsync("col")`, `client.ListSnapshotsAsync("col")` |
| Alias | `client.CreateAliasAsync("alias", "col")`, `client.DeleteAliasAsync("alias")` |
| Update collection | `client.UpdateCollectionAsync("col", optimizersConfig: new OptimizersConfigDiff { ... })` |

## Gotchas

- gRPC only (port 6334). Not REST.
- `IDisposable`. Always `using var client = ...`.
- Implicit operators everywhere. `float[]` becomes `Vectors`/`Query`. `string` becomes `Value`. `ulong` becomes `PointId`.
- Use `&`/`|`/`!` for filter logic, NOT `&&`/`||` (C# limitation).
- `ulong` IDs need `ul` suffix. `42` is `int`, use `42ul`.
- Payload values are `Value` protobuf objects. Implicit from `string`/`long`/`bool`/`double` on write. Read via `.StringValue`, `.IntegerValue`, etc.
- `UpsertAsync` defaults `wait: true`. Writes block.
- `SearchAsync` and `QueryAsync` both exist. `QueryAsync` is the modern unified API.
- Scroll needs `.Result` for points and `.NextPageOffset` for cursor.
- All methods end with `Async`. Don't forget `await`.
- Errors throw `RpcException`. Collection not found is `StatusCode.NotFound`.
- Never one collection per user. Use tenant payload index.
- Vector dims must match collection config on every upsert and query.
- Distance is immutable. Delete and recreate collection to change.
