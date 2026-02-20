# Advanced Indexing and Quantization

HNSW, quantization, and multi-vector configuration in Go.

## HNSW Parameters

```go
client.CreateCollection(ctx, &qdrant.CreateCollection{
    CollectionName: "col",
    VectorsConfig: qdrant.NewVectorsConfig(&qdrant.VectorParams{
        Size: 768, Distance: qdrant.Distance_Cosine,
    }),
    HnswConfig: &qdrant.HnswConfigDiff{
        M:                  qdrant.PtrOf(uint64(16)),
        EfConstruct:        qdrant.PtrOf(uint64(100)),
        FullScanThreshold:  qdrant.PtrOf(uint64(10000)),
    },
})

// Tune after creation
client.UpdateCollection(ctx, &qdrant.UpdateCollection{
    CollectionName: "col",
    HnswConfig: &qdrant.HnswConfigDiff{
        M:           qdrant.PtrOf(uint64(32)),
        EfConstruct: qdrant.PtrOf(uint64(200)),
    },
})
```

### Search-Time ef

```go
client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "col",
    Query:          qdrant.NewQuery(0.2, 0.1, 0.9),
    Params: &qdrant.SearchParams{
        HnswEf: qdrant.PtrOf(uint64(128)),
    },
    Limit: qdrant.PtrOf(uint64(10)),
})
```

## Scalar Quantization

```go
client.CreateCollection(ctx, &qdrant.CreateCollection{
    CollectionName: "col",
    VectorsConfig: qdrant.NewVectorsConfig(&qdrant.VectorParams{
        Size: 768, Distance: qdrant.Distance_Cosine,
    }),
    QuantizationConfig: &qdrant.QuantizationConfig{
        Quantization: &qdrant.QuantizationConfig_Scalar{
            Scalar: &qdrant.ScalarQuantization{
                Type:      qdrant.QuantizationType_Int8,
                Quantile:  qdrant.PtrOf(float32(0.99)),
                AlwaysRam: qdrant.PtrOf(true),
            },
        },
    },
})
```

## Product Quantization

```go
QuantizationConfig: &qdrant.QuantizationConfig{
    Quantization: &qdrant.QuantizationConfig_Product{
        Product: &qdrant.ProductQuantization{
            Compression: qdrant.CompressionRatio_x16,
            AlwaysRam:   qdrant.PtrOf(true),
        },
    },
}
```

## Binary Quantization

```go
QuantizationConfig: &qdrant.QuantizationConfig{
    Quantization: &qdrant.QuantizationConfig_Binary{
        Binary: &qdrant.BinaryQuantization{
            AlwaysRam: qdrant.PtrOf(true),
        },
    },
}
```

## Quantization Search Params

```go
client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "col",
    Query:          qdrant.NewQuery(0.2, 0.1, 0.9),
    Params: &qdrant.SearchParams{
        Quantization: &qdrant.QuantizationSearchParams{
            Rescore:      qdrant.PtrOf(true),
            Oversampling: qdrant.PtrOf(2.0),
        },
    },
})
```

## Multi-Vector (ColBERT)

```go
client.CreateCollection(ctx, &qdrant.CreateCollection{
    CollectionName: "col",
    VectorsConfig: qdrant.NewVectorsConfig(&qdrant.VectorParams{
        Size:     128,
        Distance: qdrant.Distance_Cosine,
        MultivectorConfig: &qdrant.MultiVectorConfig{
            Comparator: qdrant.MultiVectorComparator_MaxSim,
        },
    }),
})
```

## What's Mutable at Runtime

| Parameter | Mutable | Method |
|-----------|---------|--------|
| Distance | No | Recreate collection |
| Vector size | No | Recreate collection |
| HNSW `m`, `ef_construct` | Yes | `UpdateCollection` |
| Quantization | Yes | `UpdateCollection` |
| Optimizer settings | Yes | `UpdateCollection` |
| On-disk flag | No | Set at creation |
| Multi-vector comparator | No | Recreate collection |
