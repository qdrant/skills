# Factory Classes Reference

Complete reference for Qdrant Java client factory classes and builder patterns.

## Essential Static Imports

These imports are critical for writing readable code:

```java
import static io.qdrant.client.PointIdFactory.id;
import static io.qdrant.client.ValueFactory.value;
import static io.qdrant.client.VectorsFactory.vectors;
import static io.qdrant.client.VectorFactory.vector;
import static io.qdrant.client.VectorsFactory.namedVectors;
import static io.qdrant.client.VectorInputFactory.vectorInput;
import static io.qdrant.client.QueryFactory.nearest;
import static io.qdrant.client.QueryFactory.fusion;
import static io.qdrant.client.QueryFactory.orderBy;
import static io.qdrant.client.QueryFactory.recommend;
import static io.qdrant.client.QueryFactory.discover;
import static io.qdrant.client.ConditionFactory.*;
import static io.qdrant.client.WithPayloadSelectorFactory.enable;
import static io.qdrant.client.WithVectorsSelectorFactory.enable as enableVectors;
```

## PointIdFactory

```java
id(42)                          // numeric ID (long)
id(UUID.randomUUID())           // UUID ID
id("550e8400-e29b-41d4-...")    // UUID from string
```

## ValueFactory

Wraps Java types into protobuf `Value` for payloads:

```java
value("Berlin")                 // string
value(42L)                      // long integer
value(3.14)                     // double
value(true)                     // boolean
value((Object) null)            // null value
value(List.of(                  // list of values
    value("a"), value("b")
))
value(Map.of(                   // struct (nested object)
    "nested_key", value("nested_val")
))
```

## VectorsFactory vs VectorFactory

This is a common source of confusion:

- `vectors(...)` (plural): creates `Vectors` wrapper for `PointStruct.setVectors()`
- `vector(...)` (singular): creates `Vector` for named vector maps

### VectorsFactory (for PointStruct)

```java
// Unnamed dense vector (variadic)
vectors(0.1f, 0.2f, 0.3f)

// Unnamed dense vector (from list)
vectors(List.of(0.1f, 0.2f, 0.3f))
```

### VectorFactory (for named vectors)

```java
// Dense vector for named maps
vector(List.of(0.1f, 0.2f, 0.3f))

// Sparse vector
vector(List.of(0.5f, 0.8f), List.of(1, 42))    // values, indices
```

### Named Vectors (combining both)

```java
// namedVectors wraps a map of name -> Vector into Vectors
PointStruct.newBuilder()
    .setId(id(1))
    .setVectors(namedVectors(Map.of(
        "image", vector(List.of(0.9f, 0.1f, 0.1f, 0.2f)),
        "text", vector(List.of(0.4f, 0.7f, 0.1f, 0.8f))
    )))
    .build();
```

## VectorInputFactory

Creates `VectorInput` for recommend/discover queries:

```java
vectorInput(0.1f, 0.2f, 0.3f)              // dense vector
vectorInput(List.of(0.1f, 0.2f))            // dense from list
vectorInput(id(42))                          // by point ID
vectorInput(id(UUID.randomUUID()))           // by UUID
```

## QueryFactory

### nearest (vector similarity)

```java
// Dense vector (variadic)
nearest(0.2f, 0.1f, 0.9f)

// Dense vector (from list)
nearest(List.of(0.2f, 0.1f, 0.9f))

// Sparse vector (values, indices)
nearest(List.of(0.22f, 0.8f), List.of(1, 42))

// By point ID
nearest(id(42))
nearest(id(UUID.randomUUID()))

// Multi-vector (array of vectors)
nearest(new float[][] {{0.1f, 0.2f}, {0.3f, 0.4f}})

// With MMR diversity
nearest(vectorInput(0.1f, 0.2f, 0.3f),
    Mmr.newBuilder().setDiversity(0.5f).build())
```

### fusion

```java
fusion(Fusion.RRF)      // Reciprocal Rank Fusion
fusion(Fusion.DBSF)     // Distribution-Based Score Fusion
```

### orderBy

```java
orderBy("timestamp")    // order by payload field (no vector similarity)
```

### recommend

```java
recommend(List.of(vectorInput(id(1)), vectorInput(id(2))),   // positive
          List.of(vectorInput(id(3))))                         // negative
```

### discover

```java
discover(
    vectorInput(id(1)),                    // target
    List.of(new ContextInputPair(          // context pairs
        vectorInput(id(2)),                // positive
        vectorInput(id(3))                 // negative
    ))
)
```

## ConditionFactory

### Match conditions

```java
matchKeyword("city", "Berlin")                    // exact keyword
matchText("description", "vector database")        // full-text (needs text index)
match("active", true)                              // boolean
match("count", 42L)                                // integer
matchKeywords("color", List.of("red", "blue"))     // any-of (keywords)
matchExceptKeywords("status", List.of("deleted"))  // none-of (keywords)
matchIntegers("code", List.of(200L, 201L))         // any-of (integers)
matchExceptIntegers("code", List.of(500L, 502L))   // none-of (integers)
```

### Range

```java
range("price", Range.newBuilder()
    .setGte(10.0)
    .setLte(100.0)
    .build())
```

### Datetime range

```java
import com.google.protobuf.Timestamp;

datetimeRange("created_at", DatetimeRange.newBuilder()
    .setGte(Timestamp.newBuilder().setSeconds(startEpoch).build())
    .setLt(Timestamp.newBuilder().setSeconds(endEpoch).build())
    .build())
```

### Geo conditions

```java
geoRadius("location", 52.52, 13.40, 1000.0f)      // lat, lon, radius (meters)

geoBoundingBox("location",
    52.52, 13.35,    // top-left lat, lon
    52.50, 13.45)    // bottom-right lat, lon
```

### Existence checks

```java
hasId(id(1))
hasId(id(1), id(2), id(3))
isEmpty("tags")
isNull("email")
```

### Nested

```java
nested("reviews", matchKeyword("reviews[].verdict", "positive"))
nested("reviews",
    Filter.newBuilder()
        .addMust(range("reviews[].score", Range.newBuilder().setGte(4.0).build()))
        .addMust(match("reviews[].verified", true))
        .build())
```

## Filter Building

```java
// Simple filter (single condition auto-wraps into must)
Filter.newBuilder()
    .addMust(matchKeyword("category", "electronics"))
    .build()

// Complex filter
Filter.newBuilder()
    .addAllMust(List.of(
        matchKeyword("category", "electronics"),
        range("price", Range.newBuilder().setLte(100.0).build())
    ))
    .addAllShould(List.of(
        matchKeyword("brand", "Apple"),
        matchKeyword("brand", "Samsung")
    ))
    .addAllMustNot(List.of(
        match("discontinued", true)
    ))
    .build()
```

## WithPayloadSelectorFactory

```java
enable(true)                // all payload
enable(List.of("field1", "field2"))  // specific fields
```

## Payload Schema Types

For `createPayloadIndexAsync`:

```java
PayloadSchemaType.Keyword
PayloadSchemaType.Integer
PayloadSchemaType.Float
PayloadSchemaType.Geo
PayloadSchemaType.Text
PayloadSchemaType.Bool
PayloadSchemaType.Datetime
PayloadSchemaType.Uuid
```

## Common Builder Patterns

### Collection with named vectors

```java
client.createCollectionAsync("col", Map.of(
    "dense", VectorParams.newBuilder()
        .setSize(768).setDistance(Distance.Cosine).build(),
    "image", VectorParams.newBuilder()
        .setSize(512).setDistance(Distance.Euclid).build()
)).get();
```

### Sparse vector collection config

```java
client.createCollectionAsync(CreateCollection.newBuilder()
    .setCollectionName("col")
    .setVectorsConfig(VectorsConfig.newBuilder()
        .setParamsMap(VectorParamsMap.newBuilder()
            .putMap("dense", VectorParams.newBuilder()
                .setSize(768).setDistance(Distance.Cosine).build())
            .build()))
    .setSparseVectorsConfig(SparseVectorConfig.newBuilder()
        .putMap("sparse", SparseVectorParams.newBuilder()
            .setModifier(Modifier.Idf)
            .build())
        .build())
    .build()
).get();
```

### Full query with all options

```java
client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("col")
    .setQuery(nearest(0.2f, 0.1f, 0.9f))
    .setFilter(Filter.newBuilder()
        .addMust(matchKeyword("category", "electronics"))
        .build())
    .setWithPayload(enable(true))
    .setLimit(10)
    .setScoreThreshold(0.5f)
    .setUsing("dense")
    .build()
).get();
```
