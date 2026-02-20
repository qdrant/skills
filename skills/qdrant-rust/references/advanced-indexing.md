# Advanced Indexing and Quantization

Tuning HNSW, quantization, and multi-vector configuration in Rust.

## HNSW Parameters

```rust
use qdrant_client::qdrant::{
    CreateCollectionBuilder, VectorParamsBuilder, Distance,
    HnswConfigDiffBuilder,
};

// At creation
client.create_collection(
    CreateCollectionBuilder::new("col")
        .vectors_config(VectorParamsBuilder::new(768, Distance::Cosine))
        .hnsw_config(HnswConfigDiffBuilder::default()
            .m(16)                    // connections per node
            .ef_construct(100)        // search width during build
            .full_scan_threshold(10000)),
).await?;

// Tune after creation
client.update_collection(
    UpdateCollectionBuilder::new("col")
        .hnsw_config(HnswConfigDiffBuilder::default()
            .m(32)
            .ef_construct(200)),
).await?;
```

### Search-Time ef

```rust
use qdrant_client::qdrant::SearchParamsBuilder;

client.query(
    QueryPointsBuilder::new("col")
        .query(vec![0.2, 0.1, 0.9])
        .params(SearchParamsBuilder::default().hnsw_ef(128))
        .limit(10u64),
).await?;
```

## Scalar Quantization

4x memory reduction with minimal quality loss:

```rust
use qdrant_client::qdrant::{QuantizationType, ScalarQuantizationBuilder};

client.create_collection(
    CreateCollectionBuilder::new("col")
        .vectors_config(VectorParamsBuilder::new(768, Distance::Cosine))
        .quantization_config(ScalarQuantizationBuilder::default()
            .r#type(QuantizationType::Int8.into())
            .quantile(0.99f32)
            .always_ram(true)),
).await?;
```

## Product Quantization

Higher compression for large datasets:

```rust
use qdrant_client::qdrant::{ProductQuantizationBuilder, CompressionRatio};

client.create_collection(
    CreateCollectionBuilder::new("col")
        .vectors_config(VectorParamsBuilder::new(768, Distance::Cosine))
        .quantization_config(ProductQuantizationBuilder::default()
            .compression(CompressionRatio::X16.into())
            .always_ram(true)),
).await?;
```

## Binary Quantization

32x compression, for normalized vectors with Cosine distance only:

```rust
use qdrant_client::qdrant::BinaryQuantizationBuilder;

client.create_collection(
    CreateCollectionBuilder::new("col")
        .vectors_config(VectorParamsBuilder::new(768, Distance::Cosine))
        .quantization_config(BinaryQuantizationBuilder::default()
            .always_ram(true)),
).await?;
```

## Quantization Search Params

```rust
use qdrant_client::qdrant::{SearchParamsBuilder, QuantizationSearchParamsBuilder};

client.query(
    QueryPointsBuilder::new("col")
        .query(vec![0.2, 0.1, 0.9])
        .params(SearchParamsBuilder::default()
            .quantization(QuantizationSearchParamsBuilder::default()
                .rescore(true)
                .oversampling(2.0)))
        .limit(10u64),
).await?;
```

## On-Disk Vectors

```rust
client.create_collection(
    CreateCollectionBuilder::new("col")
        .vectors_config(
            VectorParamsBuilder::new(768, Distance::Cosine)
                .on_disk(true))
        .hnsw_config(HnswConfigDiffBuilder::default()
            .on_disk(true))
        .quantization_config(ScalarQuantizationBuilder::default()
            .r#type(QuantizationType::Int8.into())
            .always_ram(true)),
).await?;
```

## Multi-Vector (ColBERT)

```rust
use qdrant_client::qdrant::{
    MultiVectorConfig, MultiVectorComparator, VectorParamsBuilder,
};

// Single multi-vector collection
client.create_collection(
    CreateCollectionBuilder::new("col")
        .vectors_config(
            VectorParamsBuilder::new(128, Distance::Cosine)
                .multivector_config(MultiVectorConfig {
                    comparator: MultiVectorComparator::MaxSim.into(),
                })),
).await?;

// Two-stage: dense retrieval + ColBERT reranking
let mut vectors = VectorParamsMap::new();
vectors.insert("dense", VectorParamsBuilder::new(768, Distance::Cosine));
vectors.insert("colbert",
    VectorParamsBuilder::new(128, Distance::Cosine)
        .multivector_config(MultiVectorConfig {
            comparator: MultiVectorComparator::MaxSim.into(),
        })
        .hnsw_config(HnswConfigDiffBuilder::default().m(0u64)));  // disable HNSW

client.create_collection(
    CreateCollectionBuilder::new("col").vectors_config(vectors),
).await?;
```

## Optimizer Config

```rust
use qdrant_client::qdrant::OptimizersConfigDiffBuilder;

client.update_collection(
    UpdateCollectionBuilder::new("col")
        .optimizers_config(OptimizersConfigDiffBuilder::default()
            .indexing_threshold(20000u64)
            .memmap_threshold(50000u64)
            .default_segment_number(4u64)
            .max_optimization_threads(2u64)),
).await?;
```

## What's Mutable at Runtime

| Parameter | Mutable | Method |
|-----------|---------|--------|
| Distance | No | Recreate collection |
| Vector size | No | Recreate collection |
| HNSW `m`, `ef_construct` | Yes | `update_collection` |
| Quantization | Yes | `update_collection` |
| Optimizer settings | Yes | `update_collection` |
| On-disk flag | No | Set at creation |
| Multi-vector comparator | No | Recreate collection |
