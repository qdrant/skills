---
name: qdrant-java
description: "Best practices for the Qdrant Java client (io.qdrant:client). Use when writing Java code that uses Qdrant. Covers client setup, query, filtering, hybrid search with prefetch, and common gotchas."
allowed-tools: Read Grep Glob
license: Apache-2.0
metadata:
  author: qdrant
  version: "1.0"
---

# Qdrant Java Client

You interact with Qdrant over gRPC (port 6334) using the `io.qdrant:client` Maven artifact. All types are protobuf-generated. Every method returns `ListenableFuture<T>` (call `.get()` to block).

## Setup

**Maven:**
```xml
<dependency>
  <groupId>io.qdrant</groupId>
  <artifactId>client</artifactId>
  <version>1.16.2</version>
</dependency>
```

**Gradle:**
```gradle
implementation 'io.qdrant:client:1.16.2'
```

```java
import io.qdrant.client.QdrantClient;
import io.qdrant.client.QdrantGrpcClient;

// Local
QdrantClient client = new QdrantClient(
    QdrantGrpcClient.newBuilder("localhost", 6334, false).build());

// Cloud
QdrantClient client = new QdrantClient(
    QdrantGrpcClient.newBuilder("xyz.cloud.qdrant.io", 6334, true)
        .withApiKey("<api-key>")
        .build());
```

## Essential Static Imports

```java
import static io.qdrant.client.PointIdFactory.id;
import static io.qdrant.client.ValueFactory.value;
import static io.qdrant.client.VectorsFactory.vectors;
import static io.qdrant.client.VectorFactory.vector;
import static io.qdrant.client.VectorsFactory.namedVectors;
import static io.qdrant.client.VectorInputFactory.vectorInput;
import static io.qdrant.client.QueryFactory.nearest;
import static io.qdrant.client.QueryFactory.fusion;
import static io.qdrant.client.ConditionFactory.*;
import static io.qdrant.client.WithPayloadSelectorFactory.enable;
```

## Decision Table

| Want to... | Do |
|-----------|-----|
| Create collection | `client.createCollectionAsync("col", VectorParams.newBuilder().setSize(768).setDistance(Distance.Cosine).build())` |
| Upsert | `client.upsertAsync("col", List.of(PointStruct.newBuilder().setId(id(1)).setVectors(vectors(0.1f, 0.2f)).putAllPayload(Map.of("k", value("v"))).build()))` |
| Query | `client.queryAsync(QueryPoints.newBuilder().setCollectionName("col").setQuery(nearest(0.2f, 0.1f)).setLimit(10).build())` |
| Query with filter | `.setFilter(Filter.newBuilder().addMust(matchKeyword("field", "value")).build())` |
| Hybrid (RRF) | `.addPrefetch(PrefetchQuery.newBuilder()...)` with `.setQuery(fusion(Fusion.RRF))` |
| Named vector query | `.setUsing("image")` on `QueryPoints` |
| Scroll | `client.scrollAsync(ScrollPoints.newBuilder().setCollectionName("col").setLimit(100).build())` |
| Delete by IDs | `client.deleteAsync("col", List.of(id(0), id(1)))` |
| Delete by filter | `client.deleteAsync("col", Filter.newBuilder().addMust(...).build())` |
| Payload index | `client.createPayloadIndexAsync("col", "field", PayloadSchemaType.Keyword, null, null, null, null)` |
| Recommend | `setQuery(recommend(List.of(vectorInput(id(1))), List.of(vectorInput(id(3)))))` |
| Discover | `setQuery(discover(vectorInput(id(1)), List.of(new ContextInputPair(vectorInput(id(2)), vectorInput(id(3))))))` |
| Set payload | `client.setPayloadAsync("col", Map.of("k", value("v")), List.of(id(1)), null, null)` |
| Delete payload keys | `client.deletePayloadAsync("col", List.of("key1"), List.of(id(1)), null, null)` |
| Clear payload | `client.clearPayloadAsync("col", List.of(id(1)), null, null)` |
| Create snapshot | `client.createSnapshotAsync("col")` |
| List snapshots | `client.listSnapshotAsync("col")` |
| Create alias | `client.createAliasAsync("alias", "col")` |
| Delete alias | `client.deleteAliasAsync("alias")` |
| Update collection | `client.updateCollectionAsync(UpdateCollection.newBuilder().setCollectionName("col").setOptimizersConfig(...).build())` |

## Query with Filter

```java
client.queryAsync(
    QueryPoints.newBuilder()
        .setCollectionName("products")
        .setQuery(nearest(0.2f, 0.1f, 0.9f, 0.7f))
        .setFilter(Filter.newBuilder()
            .addMust(matchKeyword("category", "electronics"))
            .build())
        .setWithPayload(enable(true))
        .setLimit(10)
        .build()
).get();
```

## Upsert with Payload

```java
client.upsertAsync("col", List.of(
    PointStruct.newBuilder()
        .setId(id(1))
        .setVectors(vectors(0.1f, 0.2f, 0.3f))
        .putAllPayload(Map.of(
            "city", value("London"),
            "population", value(9_000_000L),
            "active", value(true)))
        .build()
)).get();
```

## Hybrid Search (Dense + Sparse with RRF)

```java
client.queryAsync(
    QueryPoints.newBuilder()
        .setCollectionName("col")
        .addPrefetch(PrefetchQuery.newBuilder()
            .setQuery(nearest(List.of(0.22f, 0.8f), List.of(1, 42)))
            .setUsing("sparse")
            .setLimit(20)
            .build())
        .addPrefetch(PrefetchQuery.newBuilder()
            .setQuery(nearest(0.01f, 0.45f, 0.67f))
            .setUsing("dense")
            .setLimit(20)
            .build())
        .setQuery(fusion(Fusion.RRF))
        .setLimit(10)
        .build()
).get();
```

## Named Vectors

```java
// Create
client.createCollectionAsync("col", Map.of(
    "image", VectorParams.newBuilder().setSize(4).setDistance(Distance.Dot).build(),
    "text", VectorParams.newBuilder().setSize(8).setDistance(Distance.Cosine).build()
)).get();

// Upsert
client.upsertAsync("col", List.of(
    PointStruct.newBuilder()
        .setId(id(1))
        .setVectors(namedVectors(Map.of(
            "image", vector(List.of(0.9f, 0.1f, 0.1f, 0.2f)),
            "text", vector(List.of(0.4f, 0.7f, 0.1f, 0.8f)))))
        .build()
)).get();

// Query specific vector
client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("col")
    .setQuery(nearest(0.9f, 0.1f, 0.1f, 0.2f))
    .setUsing("image")
    .build()
).get();
```

## Filtering (ConditionFactory)

```java
import static io.qdrant.client.ConditionFactory.*;

// Match
matchKeyword("city", "Berlin")               // exact keyword
matchText("desc", "vector database")          // full-text search
match("active", true)                         // boolean
match("count", 42L)                           // integer
matchKeywords("color", List.of("red", "blue"))   // any-of
matchExceptKeywords("status", List.of("deleted")) // none-of

// Range
range("price", Range.newBuilder().setGte(10.0).setLte(100.0).build())

// Datetime
datetimeRange("date", DatetimeRange.newBuilder()
    .setGte(Timestamps.fromMillis(start)).setLt(Timestamps.fromMillis(end)).build())

// Geo
geoRadius("location", 52.52, 13.40, 1000.0f)

// Existence
hasId(id(1))
isEmpty("tags")
isNull("email")

// Nested
nested("reviews", matchKeyword("reviews[].verdict", "positive"))

// Compose
Filter.newBuilder()
    .addAllMust(List.of(...))
    .addAllShould(List.of(...))
    .addAllMustNot(List.of(...))
    .build()
```

## MMR (Diversity)

```java
client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("col")
    .setQuery(nearest(
        vectorInput(0.01f, 0.45f, 0.67f),
        Mmr.newBuilder().setDiversity(0.5f).build()))
    .setLimit(10)
    .build()
).get();
```

## Recommend (Find Similar)

```java
import static io.qdrant.client.QueryFactory.recommend;

client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("products")
    .setQuery(recommend(
        List.of(vectorInput(id(1)), vectorInput(id(2))),  // positive
        List.of(vectorInput(id(3)))))                       // negative
    .setLimit(10)
    .build()
).get();
```

## Payload Mutation

```java
// Set payload (merge)
client.setPayloadAsync("col",
    Map.of("status", value("reviewed")),
    List.of(id(1), id(2)), null, null).get();

// Delete specific keys
client.deletePayloadAsync("col",
    List.of("temp_field"),
    List.of(id(1)), null, null).get();

// Clear all payload
client.clearPayloadAsync("col", List.of(id(1)), null, null).get();
```

## Collection Aliases

```java
// Zero-downtime swap
client.deleteAliasAsync("production").get();
client.createAliasAsync("production", "products_v2").get();
```

## Gotchas

- **gRPC only, port 6334**: Not REST. Port 6333 won't work.
- **Everything returns `ListenableFuture<T>`**: Call `.get()` to block. No synchronous API.
- **Builder pattern everywhere**: `VectorParams.newBuilder()...build()`. Very verbose compared to Python dicts.
- **Factory classes are essential**: Without `import static` for `id()`, `value()`, `vectors()`, `nearest()`, `matchKeyword()`, etc., code is extremely verbose.
- **`vectors()` vs `vector()`**: Plural `vectors()` creates the `Vectors` wrapper for `PointStruct`. Singular `vector()` creates a `Vector` for named vector maps.
- **Protobuf types, not POJOs**: All response types use getters: `.getId()`, `.getPayloadMap()`, `.getScore()`.
- **Payload values need `value()` wrapper**: `value("string")`, `value(42L)`, `value(true)`. Raw Java types don't work.
- **`nearest()` has many overloads**: `float...`, `List<Float>`, `long` (point ID), `UUID`, `float[][]` (multi-vector), sparse via `List<Float>, List<Integer>`.
- **Sparse vector upsert is verbose**: Must build `Vectors > NamedVectors > Map<String, Vector>` manually.
- **Channel lifecycle**: When using custom `ManagedChannel`, pass `true` as second arg to auto-shutdown on close.
- **`searchAsync` (legacy) uses `addAllVector()`**: The modern `queryAsync` with `nearest()` is preferred.
- **`PayloadSchemaType.Keyword`**: Index types are `Keyword`, `Integer`, `Float`, `Geo`, `Text`, `Bool`, `Datetime`, `Uuid`.
- **Never one collection per user**: Use tenant payload index with `IsTenant(true)`.
- **Vector size must match**: Every upsert and query must match collection dims.
- **Distance is immutable**: Delete and recreate collection to change it.

## Read More

- [Maven Central: io.qdrant:client](https://central.sonatype.com/artifact/io.qdrant/client)
- [GitHub: qdrant/java-client](https://github.com/qdrant/java-client)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
