# Advanced Indexing and Quantization

Tuning HNSW parameters, quantization, and multi-vector configuration for production workloads.

## HNSW Parameters

HNSW (Hierarchical Navigable Small World) is the vector index algorithm. Key parameters:

```python
from qdrant_client.models import HnswConfigDiff

# At collection creation
client.create_collection("col",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
    hnsw_config=HnswConfigDiff(
        m=16,                # connections per node (default: 16)
        ef_construct=100,    # search width during build (default: 100)
        full_scan_threshold=10000,  # below this, skip HNSW
    ))

# Tune after creation
client.update_collection("col",
    hnsw_config=HnswConfigDiff(m=32, ef_construct=200))
```

### Parameter Guide

| Parameter | Default | Effect of increasing |
|-----------|---------|---------------------|
| `m` | 16 | Better recall, more memory, slower build |
| `ef_construct` | 100 | Better recall, slower build |
| `full_scan_threshold` | 10000 | Larger collections use brute-force (exact) search |

### Search-Time ef

`ef` controls search precision at query time (higher = better recall, slower):

```python
from qdrant_client.models import SearchParams

client.query_points("col",
    query=vector,
    search_params=SearchParams(hnsw_ef=128),  # default: same as ef_construct
    limit=10)
```

### When to Tune

- **Recall too low**: Increase `ef_construct` and `m`
- **Build too slow**: Decrease `ef_construct` (128 is usually enough)
- **High memory**: Decrease `m` (8 works for small datasets)
- **Search too slow**: Decrease `hnsw_ef` at query time (trade recall for speed)

## Quantization

Reduces memory by compressing vectors. Three modes:

### Scalar Quantization (fastest, least compression)

Converts float32 to int8. 4x memory reduction with minimal quality loss.

```python
from qdrant_client.models import ScalarQuantization, ScalarQuantizationConfig, ScalarType

client.create_collection("col",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
    quantization_config=ScalarQuantization(
        scalar=ScalarQuantizationConfig(
            type=ScalarType.INT8,
            quantile=0.99,        # clip outliers
            always_ram=True,      # keep quantized vectors in RAM
        )))
```

### Product Quantization (most compression)

Compresses vectors into sub-vector codes. Higher compression, more quality loss.

```python
from qdrant_client.models import ProductQuantization, ProductQuantizationConfig

client.create_collection("col",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
    quantization_config=ProductQuantization(
        product=ProductQuantizationConfig(
            compression=CompressionRatio.X16,  # X4, X8, X16, X32, X64
            always_ram=True,
        )))
```

### Binary Quantization (for normalized vectors only)

Converts each float to a single bit. 32x compression. Only works well with Cosine distance on normalized vectors.

```python
from qdrant_client.models import BinaryQuantization, BinaryQuantizationConfig

client.create_collection("col",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
    quantization_config=BinaryQuantization(
        binary=BinaryQuantizationConfig(always_ram=True)))
```

### Quantization Search Params

Use oversampling and rescoring for better quality with quantized vectors:

```python
from qdrant_client.models import SearchParams, QuantizationSearchParams

client.query_points("col",
    query=vector,
    search_params=SearchParams(
        quantization=QuantizationSearchParams(
            rescore=True,    # re-rank with original vectors
            oversampling=2.0,  # fetch 2x candidates before rescoring
        )),
    limit=10)
```

### When to Use Each

| Method | Memory savings | Quality loss | Best for |
|--------|---------------|-------------|----------|
| Scalar (int8) | 4x | Minimal | Default choice |
| Product | 16-64x | Moderate | Very large datasets |
| Binary | 32x | Varies | Normalized embeddings with Cosine |

## On-Disk Vectors

For datasets that exceed RAM, store vectors on disk:

```python
client.create_collection("col",
    vectors_config=VectorParams(
        size=768,
        distance=Distance.COSINE,
        on_disk=True,  # store vectors on disk
    ),
    hnsw_config=HnswConfigDiff(on_disk=True),  # store HNSW index on disk too
    quantization_config=ScalarQuantization(
        scalar=ScalarQuantizationConfig(
            type=ScalarType.INT8,
            always_ram=True,  # keep quantized vectors in RAM for fast search
        )))
```

This pattern stores original vectors on disk but keeps the quantized versions in RAM. Searches use RAM-resident quantized vectors for speed, then rescore from disk for accuracy.

## Multi-Vector (ColBERT / Late Interaction)

Store token-level embeddings for late interaction models like ColBERT:

```python
from qdrant_client.models import (
    VectorParams, MultiVectorConfig, MultiVectorComparator,
)

# Create collection with multi-vector support
client.create_collection("col",
    vectors_config=VectorParams(
        size=128,  # per-token dimension
        distance=Distance.COSINE,
        multivector_config=MultiVectorConfig(
            comparator=MultiVectorComparator.MAX_SIM,
        ),
    ))

# Upsert: each point's vector is a list of token vectors (matrix)
client.upsert("col", points=[
    PointStruct(
        id=1,
        vector=[[0.1, 0.2, ...], [0.3, 0.4, ...], [0.5, 0.6, ...]],  # N tokens x 128 dims
        payload={"text": "document text"},
    ),
])

# Query: pass a list of query token vectors
client.query_points("col",
    query=[[0.1, 0.2, ...], [0.3, 0.4, ...]],  # query tokens
    limit=10)
```

### Multi-Vector with HNSW Disabled (Reranking Only)

For large-scale ColBERT, disable HNSW on multi-vectors and use them only for reranking:

```python
# Named vectors: dense for retrieval, multivec for reranking
client.create_collection("col",
    vectors_config={
        "dense": VectorParams(size=768, distance=Distance.COSINE),
        "colbert": VectorParams(
            size=128,
            distance=Distance.COSINE,
            multivector_config=MultiVectorConfig(
                comparator=MultiVectorComparator.MAX_SIM),
            hnsw_config=HnswConfigDiff(m=0),  # disable HNSW indexing
        ),
    })

# Two-stage: retrieve with dense, rescore with ColBERT
client.query_points("col",
    prefetch=[Prefetch(query=dense_emb, using="dense", limit=100)],
    query=colbert_token_vectors,
    using="colbert",
    limit=10)
```

## Optimizer Config

Control background optimization:

```python
from qdrant_client.models import OptimizersConfigDiff

client.update_collection("col",
    optimizer_config=OptimizersConfigDiff(
        indexing_threshold=20000,      # min segment size to trigger indexing
        memmap_threshold=50000,        # min segment size to use mmap
        default_segment_number=4,      # target number of segments
        max_optimization_threads=2,    # parallel optimization workers
    ))
```

### What's Mutable at Runtime

| Parameter | Mutable | How to Change |
|-----------|---------|--------------|
| Distance | No | Delete and recreate collection |
| Vector size | No | Delete and recreate collection |
| HNSW `m`, `ef_construct` | Yes | `update_collection(hnsw_config=...)` |
| Quantization config | Yes | `update_collection(quantization_config=...)` |
| Optimizer settings | Yes | `update_collection(optimizer_config=...)` |
| On-disk flag | No | Set at creation only |
| Multi-vector comparator | No | Delete and recreate collection |
