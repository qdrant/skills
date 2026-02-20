---
name: qdrant-dotnet
description: "Best practices for the Qdrant .NET/C# client (Qdrant.Client NuGet). Use when writing C# code that uses Qdrant. Covers client setup, query, filtering with operator overloads, and common gotchas."
allowed-tools: Read Grep Glob
license: Apache-2.0
metadata:
  author: qdrant
  version: "1.0"
---

# Qdrant .NET/C# Client

You interact with Qdrant over gRPC (port 6334) using the `Qdrant.Client` NuGet package. All methods are async and end with `Async`.

## Setup

```bash
dotnet add package Qdrant.Client
```

```csharp
using Qdrant.Client;
using Qdrant.Client.Grpc;
using static Qdrant.Client.Grpc.Conditions;

// Local
var client = new QdrantClient("localhost");

// Cloud
var client = new QdrantClient("xyz.cloud.qdrant.io", port: 6334, https: true, apiKey: "<api-key>");
```

## Decision Table

| Want to... | Do |
|-----------|-----|
| Create collection (single vector) | `client.CreateCollectionAsync("col", new VectorParams { Size = 768, Distance = Distance.Cosine })` |
| Create collection (named vectors) | `client.CreateCollectionAsync("col", new VectorParamsMap { Map = { ["dense"] = new VectorParams { ... } } })` |
| Upsert | `client.UpsertAsync("col", points)` where points is `IReadOnlyList<PointStruct>` |
| Query (modern) | `client.QueryAsync("col", query: vector, limit: 10)` |
| Query with filter | `client.QueryAsync("col", query: vec, filter: MatchKeyword("field", "value"))` |
| Hybrid (RRF) | `client.QueryAsync("col", query: Fusion.Rrf, prefetch: [...])` |
| Scroll | `client.ScrollAsync("col", limit: 100)` returns `ScrollResponse` with `.Result` and `.NextPageOffset` |
| Delete by IDs | `client.DeleteAsync("col", ids)` |
| Delete by filter | `client.DeleteAsync("col", filter)` |
| Payload index | `client.CreatePayloadIndexAsync("col", "field", PayloadSchemaType.Keyword)` |
| Count | `client.CountAsync("col")` or `client.CountAsync("col", filter)` |
| Recommend | `client.QueryAsync("col", query: new RecommendInput { Positive = { 1ul.ToVectorInput() }, Negative = { 3ul.ToVectorInput() } })` |
| Discover | `client.QueryAsync("col", query: new DiscoverInput { Target = 1ul.ToVectorInput(), Context = { ... } })` |
| Set payload | `client.SetPayloadAsync("col", payload, ids)` |
| Overwrite payload | `client.OverwritePayloadAsync("col", payload, ids)` |
| Delete payload keys | `client.DeletePayloadAsync("col", keys, ids)` |
| Clear payload | `client.ClearPayloadAsync("col", ids)` |
| Create snapshot | `client.CreateSnapshotAsync("col")` |
| List snapshots | `client.ListSnapshotsAsync("col")` |
| Create alias | `client.CreateAliasAsync("alias", "col")` |
| Delete alias | `client.DeleteAliasAsync("alias")` |
| Update collection | `client.UpdateCollectionAsync("col", optimizersConfig: new OptimizersConfigDiff { IndexingThreshold = 20000 })` |

## Query with Filter

```csharp
var results = await client.QueryAsync(
    "products",
    query: new float[] { 0.2f, 0.1f, 0.9f, 0.7f },
    filter: MatchKeyword("category", "electronics"),
    payloadSelector: true,
    limit: 10);
```

## Upsert with Payload

```csharp
var points = new List<PointStruct>
{
    new PointStruct
    {
        Id = 1ul,
        Vectors = new float[] { 0.1f, 0.2f, 0.3f },
        Payload =
        {
            ["city"] = "London",
            ["population"] = 9_000_000L,
            ["active"] = true,
        }
    }
};

await client.UpsertAsync("col", points);
```

## Hybrid Search (RRF Fusion)

```csharp
var results = await client.QueryAsync(
    "col",
    query: Fusion.Rrf,
    prefetch: new List<PrefetchQuery>
    {
        new() { Query = new float[] { 0.01f, 0.45f, 0.67f } },
        new() { Query = new float[] { 0.5f, 0.3f, 0.1f } },
    },
    limit: 10);
```

## Filtering (Operator Overloads)

The .NET client uses `&` (AND), `|` (OR), `!` (NOT) operators on conditions.

```csharp
using static Qdrant.Client.Grpc.Conditions;

// Simple conditions
MatchKeyword("city", "Berlin")
Match("active", true)
Match("count", 42L)
Range("price", new Range { Gte = 10.0, Lte = 100.0 })
DatetimeRange("date", gte: new DateTime(2024, 1, 1))
GeoRadius("location", 52.52, 13.40, 1000.0f)
IsNull("email")
IsEmpty("tags")
HasId(1ul)

// Match any / except
Match("color", new[] { "red", "blue" }.ToList())
MatchExcept("status", new[] { "deleted" }.ToList())

// Nested
Nested("reviews", Range("score", new Range { Gte = 4.0 }))

// Combine with operators
var filter = MatchKeyword("type", "doc") & !Match("archived", true);
var filter = HasId(1ul) | HasId(2ul);
```

A single `Condition` implicitly converts to a `Filter`, so you can pass conditions directly where a filter is expected.

## Named Vectors

```csharp
// Create
await client.CreateCollectionAsync("col",
    vectorsConfig: new VectorParamsMap
    {
        Map = {
            ["dense"] = new VectorParams { Size = 128, Distance = Distance.Cosine },
            ["image"] = new VectorParams { Size = 512, Distance = Distance.Euclid }
        }
    });

// Upsert
var point = new PointStruct
{
    Id = 1ul,
    Vectors = new Dictionary<string, float[]>
    {
        ["dense"] = new[] { 0.1f, 0.2f },
        ["image"] = new[] { 0.3f, 0.4f }
    }
};

// Sparse vectors
point.Vectors = ("sparse-name", new Vector(new[] { (3.5f, 0u), (4.5f, 1u) }));
```

## Payload and Vector Selectors

```csharp
// Payload
payloadSelector: true                       // all payload
payloadSelector: new[] { "field1", "field2" }  // include specific fields

// Vectors
vectorsSelector: true                       // all vectors
vectorsSelector: new[] { "dense", "image" }   // specific named vectors
```

## Recommend (Find Similar)

```csharp
var results = await client.QueryAsync("products",
    query: new RecommendInput
    {
        Positive = { 1ul.ToVectorInput(), 2ul.ToVectorInput() },
        Negative = { 3ul.ToVectorInput() },
    },
    limit: 10);
```

## Payload Mutation

```csharp
// Set (merge keys)
await client.SetPayloadAsync("col",
    new Dictionary<string, Value> { ["status"] = "reviewed" },
    ids: new ulong[] { 1, 2, 3 });

// Delete specific keys
await client.DeletePayloadAsync("col",
    new[] { "temp_field" },
    ids: new ulong[] { 1, 2 });

// Clear all payload
await client.ClearPayloadAsync("col", ids: new ulong[] { 1 });
```

## Collection Aliases

```csharp
// Zero-downtime swap
await client.DeleteAliasAsync("production");
await client.CreateAliasAsync("production", "products_v2");
```

## Gotchas

- **gRPC only, port 6334**: Not REST. The Python client defaults to REST on 6333.
- **`IDisposable`**: Always `using var client = new QdrantClient(...)` or call `.Dispose()`.
- **Implicit operators everywhere**: `float[]` converts to `Vectors`, `Vector`, `VectorInput`, or `Query`. `string` becomes `Value`. `ulong` becomes `PointId`.
- **Use `&` / `|` / `!`, not `&&` / `||`**: C# cannot overload `&&`/`||`. The bitwise-style operators are intentional.
- **`ulong` IDs need suffix**: Use `42ul` not `42`. Integer literals are `int`, not `ulong`.
- **Payload values are `Value` objects**: Implicit conversions from `string`, `long`, `bool`, `double` work on assignment. Reading back needs `.StringValue`, `.IntegerValue`, etc.
- **`UpsertAsync` `wait` defaults to `true`**: Unlike the REST API default. Writes block until committed.
- **`RecreateCollectionAsync` exists**: Convenience method that deletes then creates. Not in all clients.
- **Scroll returns `ScrollResponse`**: Access `.Result` for points and `.NextPageOffset` for cursor.
- **All methods end with `Async`**: `QueryAsync`, `UpsertAsync`, `ScrollAsync`, etc.
- **`SearchAsync` takes `ReadOnlyMemory<float>`**: But `float[]` converts implicitly.
- **Errors throw `RpcException` (gRPC)**: Collection not found gives `StatusCode.NotFound`.
- **Never one collection per user**: Use tenant payload index.
- **Vector size must match**: Every upsert and query must match collection dims.
- **Distance is immutable**: Delete and recreate collection to change it.

## Read More

- [NuGet: Qdrant.Client](https://www.nuget.org/packages/Qdrant.Client/)
- [GitHub: qdrant/qdrant-dotnet](https://github.com/qdrant/qdrant-dotnet)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
