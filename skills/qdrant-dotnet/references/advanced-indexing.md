# Advanced Indexing and Quantization

HNSW, quantization, and multi-vector configuration in .NET/C#.

## HNSW Parameters

```csharp
// At creation
await client.CreateCollectionAsync("col",
    new VectorParams { Size = 768, Distance = Distance.Cosine },
    hnswConfig: new HnswConfigDiff { M = 16, EfConstruct = 100 });

// Tune after creation
await client.UpdateCollectionAsync("col",
    hnswConfig: new HnswConfigDiff { M = 32, EfConstruct = 200 });
```

### Search-Time ef

```csharp
await client.QueryAsync("col",
    query: vector,
    searchParams: new SearchParams { HnswEf = 128 },
    limit: 10);
```

## Scalar Quantization

```csharp
await client.CreateCollectionAsync("col",
    new VectorParams { Size = 768, Distance = Distance.Cosine },
    quantizationConfig: new ScalarQuantization
    {
        Scalar = new ScalarQuantizationConfig
        {
            Type = QuantizationType.Int8,
            Quantile = 0.99f,
            AlwaysRam = true,
        }
    });
```

## Product Quantization

```csharp
await client.CreateCollectionAsync("col",
    new VectorParams { Size = 768, Distance = Distance.Cosine },
    quantizationConfig: new ProductQuantization
    {
        Product = new ProductQuantizationConfig
        {
            Compression = CompressionRatio.X16,
            AlwaysRam = true,
        }
    });
```

## Binary Quantization

```csharp
await client.CreateCollectionAsync("col",
    new VectorParams { Size = 768, Distance = Distance.Cosine },
    quantizationConfig: new BinaryQuantization
    {
        Binary = new BinaryQuantizationConfig { AlwaysRam = true }
    });
```

## Quantization Search Params

```csharp
await client.QueryAsync("col",
    query: vector,
    searchParams: new SearchParams
    {
        Quantization = new QuantizationSearchParams
        {
            Rescore = true,
            Oversampling = 2.0,
        }
    },
    limit: 10);
```

## Multi-Vector (ColBERT)

```csharp
// Single multi-vector collection
await client.CreateCollectionAsync("col",
    new VectorParams
    {
        Size = 128,
        Distance = Distance.Cosine,
        MultivectorConfig = new MultiVectorConfig
        {
            Comparator = MultiVectorComparator.MaxSim,
        }
    });

// Two-stage: dense + ColBERT reranking
await client.CreateCollectionAsync("col",
    vectorsConfig: new VectorParamsMap
    {
        Map = {
            ["dense"] = new VectorParams { Size = 768, Distance = Distance.Cosine },
            ["colbert"] = new VectorParams
            {
                Size = 128,
                Distance = Distance.Cosine,
                MultivectorConfig = new MultiVectorConfig
                {
                    Comparator = MultiVectorComparator.MaxSim,
                },
                HnswConfig = new HnswConfigDiff { M = 0 },  // disable HNSW
            }
        }
    });
```

## What's Mutable at Runtime

| Parameter | Mutable | Method |
|-----------|---------|--------|
| Distance | No | Recreate collection |
| Vector size | No | Recreate collection |
| HNSW `m`, `ef_construct` | Yes | `UpdateCollectionAsync` |
| Quantization | Yes | `UpdateCollectionAsync` |
| Optimizer settings | Yes | `UpdateCollectionAsync` |
| On-disk flag | No | Set at creation |
| Multi-vector comparator | No | Recreate collection |
