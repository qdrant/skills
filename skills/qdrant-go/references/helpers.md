# Constructor Helpers Reference

Complete reference for the Go client's constructor helpers and protobuf type patterns.

## Point ID Constructors

```go
qdrant.NewIDNum(42)           // uint64 ID
qdrant.NewID("abc-uuid")      // string ID
```

## Vector Constructors

```go
// Dense vectors (variadic floats)
qdrant.NewVectors(0.1, 0.2, 0.3)

// Dense vectors (from slice)
qdrant.NewVectorsDense([]float32{0.1, 0.2, 0.3})

// Sparse vector
qdrant.NewVectorsSparse([]uint32{1, 42}, []float32{0.22, 0.8})

// Named vectors (map of name -> vector)
qdrant.NewVectorsMap(map[string]*qdrant.Vector{
    "image": qdrant.NewVector(0.9, 0.1, 0.1, 0.2),
    "text":  qdrant.NewVector(0.4, 0.7, 0.1, 0.8),
})

// Single vector (for named vector maps)
qdrant.NewVector(0.1, 0.2, 0.3)
qdrant.NewVectorDense([]float32{0.1, 0.2, 0.3})
```

## Query Constructors

```go
// Nearest (variadic floats)
qdrant.NewQuery(0.2, 0.1, 0.9)

// Nearest (from slice)
qdrant.NewQueryDense([]float32{0.2, 0.1, 0.9})

// Sparse query
qdrant.NewQuerySparse([]uint32{1, 42}, []float32{0.22, 0.8})

// Fusion
qdrant.NewQueryFusion(qdrant.Fusion_RRF)

// Recommend (by point IDs)
qdrant.NewQueryRecommend(&qdrant.RecommendInput{
    Positive: []*qdrant.VectorInput{
        {Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(1)}},
    },
})

// Discover
qdrant.NewQueryDiscover(&qdrant.DiscoverInput{
    Target: &qdrant.VectorInput{Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(1)}},
    Context: &qdrant.ContextInput{
        Pairs: []*qdrant.ContextInputPair{{
            Positive: &qdrant.VectorInput{Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(2)}},
            Negative: &qdrant.VectorInput{Variant: &qdrant.VectorInput_Id{Id: qdrant.NewIDNum(3)}},
        }},
    },
})

// Order by payload field (no vector similarity)
qdrant.NewQueryOrderBy(&qdrant.OrderBy{Key: "timestamp"})
```

## Condition Constructors

```go
// Keyword match
qdrant.NewMatch("city", "Berlin")

// Integer match
qdrant.NewMatchInt("count", 42)

// Boolean match
qdrant.NewMatchBool("active", true)

// Any-of (keyword list)
qdrant.NewMatchKeywords("color", "red", "green", "blue")

// None-of (keyword exclude)
qdrant.NewMatchExceptKeywords("status", "deleted", "archived")

// Any-of (integer list)
qdrant.NewMatchIntegers("code", 200, 201, 204)

// None-of (integer exclude)
qdrant.NewMatchExceptIntegers("code", 500, 502, 503)

// Range
qdrant.NewRange("price", &qdrant.Range{
    Gte: qdrant.PtrOf(10.0),
    Lte: qdrant.PtrOf(100.0),
})

// Datetime range (uses timestamppb)
import "google.golang.org/protobuf/types/known/timestamppb"

qdrant.NewDatetimeRange("created_at", &qdrant.DatetimeRange{
    Gte: timestamppb.New(startTime),
    Lt:  timestamppb.New(endTime),
})

// Geo radius
qdrant.NewGeoRadius("location", 52.52, 13.40, 1000.0)

// Geo bounding box
qdrant.NewGeoBoundingBox("location",
    52.52, 13.35,   // top-left lat, lon
    52.50, 13.45,   // bottom-right lat, lon
)

// Null / Empty checks
qdrant.NewIsNull("email")
qdrant.NewIsEmpty("tags")

// Has ID
qdrant.NewHasID(qdrant.NewIDNum(1), qdrant.NewIDNum(2))

// Full-text match (requires text index)
qdrant.NewMatchText("description", "vector database")

// Nested
qdrant.NewNestedFilter("reviews", &qdrant.Filter{
    Must: []*qdrant.Condition{
        qdrant.NewRange("reviews[].score", &qdrant.Range{Gte: qdrant.PtrOf(4.0)}),
    },
})
```

## Payload Constructors

```go
// From map (panics on unsupported types)
qdrant.NewValueMap(map[string]any{
    "city":       "Berlin",
    "population": 3_500_000,
    "active":     true,
    "tags":       []any{"fast", "reliable"},
})

// Error-returning version (safe for untrusted input)
payload, err := qdrant.TryValueMap(map[string]any{...})
```

Supported types in value maps: `string`, `int`, `int64`, `float64`, `bool`, `[]any`, `map[string]any`.

## Selector Constructors

```go
// Payload selector
qdrant.NewWithPayload(true)                    // all payload
qdrant.NewWithPayloadInclude("field1", "field2") // specific fields
qdrant.NewWithPayloadExclude("secret")          // exclude fields

// Vectors selector
qdrant.NewWithVectors(true)                    // all vectors
qdrant.NewWithVectorsInclude("dense")           // specific vectors

// Points selector (for delete)
qdrant.NewPointsSelector(qdrant.NewIDNum(1), qdrant.NewIDNum(2))
qdrant.NewPointsSelectorFilter(&qdrant.Filter{...})
```

## Pointer Helper

All optional fields in protobuf structs are pointers. Use `PtrOf` for conversion:

```go
qdrant.PtrOf(uint64(10))    // *uint64
qdrant.PtrOf(uint32(100))   // *uint32
qdrant.PtrOf("image")       // *string
qdrant.PtrOf(true)          // *bool
qdrant.PtrOf(0.5)           // *float64
```

Watch types carefully. `Limit` on `QueryPoints` is `*uint64`, but `Limit` on `ScrollPoints` is `*uint32`.

## Enum Values

```go
// Distance
qdrant.Distance_Cosine
qdrant.Distance_Euclid
qdrant.Distance_Dot
qdrant.Distance_Manhattan

// Fusion
qdrant.Fusion_RRF
qdrant.Fusion_DBSF

// Field types (need .Enum() for pointer)
qdrant.FieldType_FieldTypeKeyword.Enum()
qdrant.FieldType_FieldTypeInteger.Enum()
qdrant.FieldType_FieldTypeFloat.Enum()
qdrant.FieldType_FieldTypeGeo.Enum()
qdrant.FieldType_FieldTypeDatetime.Enum()
qdrant.FieldType_FieldTypeText.Enum()
qdrant.FieldType_FieldTypeBool.Enum()
qdrant.FieldType_FieldTypeUuid.Enum()
```

## Collection Config Constructors

```go
// Single unnamed vector
qdrant.NewVectorsConfig(&qdrant.VectorParams{
    Size:     768,
    Distance: qdrant.Distance_Cosine,
})

// Named vectors
qdrant.NewVectorsConfigMap(map[string]*qdrant.VectorParams{
    "dense": {Size: 768, Distance: qdrant.Distance_Cosine},
    "image": {Size: 512, Distance: qdrant.Distance_Euclid},
})
```
