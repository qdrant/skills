# Operator Overloads and Conditions Reference

Complete reference for Qdrant .NET client filter conditions and operator composition.

## Static Import

All condition helpers require this import:

```csharp
using static Qdrant.Client.Grpc.Conditions;
```

## Condition Helpers

### Keyword Match

```csharp
MatchKeyword("city", "Berlin")
```

### Boolean Match

```csharp
Match("active", true)
```

### Integer Match

```csharp
Match("count", 42L)    // note: long, not int
```

### Match Any (IN)

```csharp
Match("color", new[] { "red", "blue" }.ToList())
```

### Match Except (NOT IN)

```csharp
MatchExcept("status", new[] { "deleted", "archived" }.ToList())
```

### Range

```csharp
Range("price", new Range { Gte = 10.0, Lte = 100.0 })
Range("count", new Range { Gt = 0 })
```

### Datetime Range

```csharp
DatetimeRange("created_at", gte: new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc))
DatetimeRange("created_at", gte: new DateTime(2024, 1, 1), lt: new DateTime(2025, 1, 1))
```

### Full-Text Match

```csharp
MatchText("description", "vector database")
```

Requires a `text` payload index on the field.

### Geo Radius

```csharp
GeoRadius("location", 52.52, 13.40, 1000.0f)    // lat, lon, radius in meters
```

### Geo Bounding Box

```csharp
GeoBoundingBox("location",
    topLeftLat: 52.52, topLeftLon: 13.35,
    bottomRightLat: 52.50, bottomRightLon: 13.45)
```

### Null and Empty

```csharp
IsNull("email")       // field is null / missing
IsEmpty("tags")       // field is empty array
```

### Has ID

```csharp
HasId(1ul)
HasId(1ul, 2ul, 3ul)
HasId("uuid-string")
```

### Nested

```csharp
Nested("reviews", Range("reviews[].score", new Range { Gte = 4.0 }))
Nested("reviews",
    MatchKeyword("reviews[].verdict", "positive")
    & Match("reviews[].verified", true))
```

## Operator Composition

The .NET client overloads `&`, `|`, and `!` on `Condition` and `Filter` types.

### AND (&)

```csharp
var filter = MatchKeyword("type", "doc") & MatchKeyword("status", "active");
```

Equivalent to `Filter { Must = [condition1, condition2] }`.

### OR (|)

```csharp
var filter = MatchKeyword("color", "red") | MatchKeyword("color", "blue");
```

Equivalent to `Filter { Should = [condition1, condition2] }`.

### NOT (!)

```csharp
var filter = !Match("archived", true);
```

Equivalent to `Filter { MustNot = [condition] }`.

### Combined

```csharp
var filter = MatchKeyword("type", "doc")
    & (MatchKeyword("color", "red") | MatchKeyword("color", "blue"))
    & !Match("archived", true);
```

### Important: Use & | ! not && || !=

C# cannot overload short-circuit operators `&&` and `||`. The bitwise-style `&` and `|` operators are intentional. Using `&&` or `||` will cause a compile error.

## Implicit Conversions

A single `Condition` implicitly converts to a `Filter`. You can pass a condition directly where a filter is expected:

```csharp
// These are equivalent:
await client.QueryAsync("col", query: vec, filter: MatchKeyword("city", "Berlin"));
await client.QueryAsync("col", query: vec,
    filter: new Filter { Must = { MatchKeyword("city", "Berlin") } });
```

Other implicit conversions:
- `float[]` converts to `Vectors`, `Vector`, `VectorInput`, or `Query`
- `string` converts to `Value`
- `ulong` converts to `PointId`
- `ReadOnlyMemory<float>` converts to vector types

## Building Filters Manually

When operator composition is not enough:

```csharp
var filter = new Filter
{
    Must =
    {
        MatchKeyword("category", "electronics"),
        Range("price", new Range { Lte = 100.0 }),
    },
    Should =
    {
        MatchKeyword("brand", "Apple"),
        MatchKeyword("brand", "Samsung"),
    },
    MustNot =
    {
        Match("discontinued", true),
    },
};
```

## Payload Selectors

```csharp
// All payload
payloadSelector: true

// Specific fields
payloadSelector: new[] { "field1", "field2" }

// Exclude fields
payloadSelector: new WithPayloadSelector
{
    Exclude = new PayloadExcludeSelector { Fields = { "secret" } }
}
```

## Vector Selectors

```csharp
// All vectors
vectorsSelector: true

// Specific named vectors
vectorsSelector: new[] { "dense", "image" }
```

## Point IDs

```csharp
// Numeric (must use ulong suffix)
PointId id = 42ul;          // correct
// PointId id = 42;         // compile error: int, not ulong

// String UUID
PointId id = Guid.NewGuid();
```

## Payload Values

Implicit conversions on assignment:

```csharp
var point = new PointStruct
{
    Id = 1ul,
    Vectors = new float[] { 0.1f, 0.2f },
    Payload =
    {
        ["city"] = "London",           // string -> Value
        ["population"] = 9_000_000L,   // long -> Value
        ["active"] = true,             // bool -> Value
        ["score"] = 0.95,              // double -> Value
    }
};
```

Reading payload values back requires explicit access:

```csharp
string city = point.Payload["city"].StringValue;
long pop = point.Payload["population"].IntegerValue;
bool active = point.Payload["active"].BoolValue;
double score = point.Payload["score"].DoubleValue;
```
