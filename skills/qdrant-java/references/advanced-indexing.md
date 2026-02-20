# Advanced Indexing and Quantization

HNSW, quantization, and multi-vector configuration in Java.

## HNSW Parameters

```java
// At creation
client.createCollectionAsync(CreateCollection.newBuilder()
    .setCollectionName("col")
    .setVectorsConfig(VectorsConfig.newBuilder()
        .setParams(VectorParams.newBuilder()
            .setSize(768).setDistance(Distance.Cosine).build()))
    .setHnswConfig(HnswConfigDiff.newBuilder()
        .setM(16)
        .setEfConstruct(100)
        .setFullScanThreshold(10000)
        .build())
    .build()).get();

// Tune after creation
client.updateCollectionAsync(UpdateCollection.newBuilder()
    .setCollectionName("col")
    .setHnswConfig(HnswConfigDiff.newBuilder()
        .setM(32)
        .setEfConstruct(200)
        .build())
    .build()).get();
```

### Search-Time ef

```java
client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("col")
    .setQuery(nearest(0.2f, 0.1f, 0.9f))
    .setParams(SearchParams.newBuilder()
        .setHnswEf(128)
        .build())
    .setLimit(10)
    .build()).get();
```

## Scalar Quantization

```java
client.createCollectionAsync(CreateCollection.newBuilder()
    .setCollectionName("col")
    .setVectorsConfig(VectorsConfig.newBuilder()
        .setParams(VectorParams.newBuilder()
            .setSize(768).setDistance(Distance.Cosine).build()))
    .setQuantizationConfig(QuantizationConfig.newBuilder()
        .setScalar(ScalarQuantization.newBuilder()
            .setType(QuantizationType.Int8)
            .setQuantile(0.99f)
            .setAlwaysRam(true)
            .build())
        .build())
    .build()).get();
```

## Product Quantization

```java
QuantizationConfig.newBuilder()
    .setProduct(ProductQuantization.newBuilder()
        .setCompression(CompressionRatio.x16)
        .setAlwaysRam(true)
        .build())
    .build()
```

## Binary Quantization

```java
QuantizationConfig.newBuilder()
    .setBinary(BinaryQuantization.newBuilder()
        .setAlwaysRam(true)
        .build())
    .build()
```

## Quantization Search Params

```java
client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("col")
    .setQuery(nearest(0.2f, 0.1f, 0.9f))
    .setParams(SearchParams.newBuilder()
        .setQuantization(QuantizationSearchParams.newBuilder()
            .setRescore(true)
            .setOversampling(2.0)
            .build())
        .build())
    .setLimit(10)
    .build()).get();
```

## Multi-Vector (ColBERT)

```java
// Single multi-vector collection
client.createCollectionAsync(CreateCollection.newBuilder()
    .setCollectionName("col")
    .setVectorsConfig(VectorsConfig.newBuilder()
        .setParams(VectorParams.newBuilder()
            .setSize(128)
            .setDistance(Distance.Cosine)
            .setMultivectorConfig(MultiVectorConfig.newBuilder()
                .setComparator(MultiVectorComparator.MaxSim)
                .build())
            .build()))
    .build()).get();

// Two-stage with named vectors
client.createCollectionAsync(CreateCollection.newBuilder()
    .setCollectionName("col")
    .setVectorsConfig(VectorsConfig.newBuilder()
        .setParamsMap(VectorParamsMap.newBuilder()
            .putMap("dense", VectorParams.newBuilder()
                .setSize(768).setDistance(Distance.Cosine).build())
            .putMap("colbert", VectorParams.newBuilder()
                .setSize(128).setDistance(Distance.Cosine)
                .setMultivectorConfig(MultiVectorConfig.newBuilder()
                    .setComparator(MultiVectorComparator.MaxSim).build())
                .setHnswConfig(HnswConfigDiff.newBuilder()
                    .setM(0).build())  // disable HNSW
                .build())
            .build()))
    .build()).get();
```

## What's Mutable at Runtime

| Parameter | Mutable | Method |
|-----------|---------|--------|
| Distance | No | Recreate collection |
| Vector size | No | Recreate collection |
| HNSW `m`, `ef_construct` | Yes | `updateCollectionAsync` |
| Quantization | Yes | `updateCollectionAsync` |
| Optimizer settings | Yes | `updateCollectionAsync` |
| On-disk flag | No | Set at creation |
| Multi-vector comparator | No | Recreate collection |
