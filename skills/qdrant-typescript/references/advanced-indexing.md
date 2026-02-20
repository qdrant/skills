# Advanced Indexing and Quantization

HNSW, quantization, and multi-vector configuration in TypeScript.

## HNSW Parameters

```typescript
// At creation
client.createCollection('col', {
    vectors: { size: 768, distance: 'Cosine' },
    hnsw_config: {
        m: 16,                    // connections per node
        ef_construct: 100,        // search width during build
        full_scan_threshold: 10000,
    },
});

// Tune after creation
client.updateCollection('col', {
    hnsw_config: { m: 32, ef_construct: 200 },
});
```

### Search-Time ef

```typescript
client.query('col', {
    query: vector,
    params: { hnsw_ef: 128 },
    limit: 10,
});
```

## Scalar Quantization

```typescript
client.createCollection('col', {
    vectors: { size: 768, distance: 'Cosine' },
    quantization_config: {
        scalar: { type: 'int8', quantile: 0.99, always_ram: true },
    },
});
```

## Product Quantization

```typescript
client.createCollection('col', {
    vectors: { size: 768, distance: 'Cosine' },
    quantization_config: {
        product: { compression: 'x16', always_ram: true },
    },
});
```

## Binary Quantization

```typescript
client.createCollection('col', {
    vectors: { size: 768, distance: 'Cosine' },
    quantization_config: {
        binary: { always_ram: true },
    },
});
```

## Quantization Search Params

```typescript
client.query('col', {
    query: vector,
    params: {
        quantization: { rescore: true, oversampling: 2.0 },
    },
    limit: 10,
});
```

## On-Disk Vectors

```typescript
client.createCollection('col', {
    vectors: { size: 768, distance: 'Cosine', on_disk: true },
    hnsw_config: { on_disk: true },
    quantization_config: {
        scalar: { type: 'int8', always_ram: true },
    },
});
```

## Multi-Vector (ColBERT)

```typescript
// Single multi-vector collection
client.createCollection('col', {
    vectors: {
        size: 128,
        distance: 'Cosine',
        multivector_config: { comparator: 'max_sim' },
    },
});

// Upsert: vector is array of token vectors
client.upsert('col', {
    points: [{
        id: 1,
        vector: [[0.1, 0.2, ...], [0.3, 0.4, ...], [0.5, 0.6, ...]],
        payload: { text: 'document' },
    }],
});

// Query with token vectors
client.query('col', {
    query: [[0.1, 0.2, ...], [0.3, 0.4, ...]],
    limit: 10,
});

// Two-stage: dense retrieval + ColBERT reranking
client.createCollection('col', {
    vectors: {
        dense: { size: 768, distance: 'Cosine' },
        colbert: {
            size: 128,
            distance: 'Cosine',
            multivector_config: { comparator: 'max_sim' },
            hnsw_config: { m: 0 },  // disable HNSW
        },
    },
});
```

## What's Mutable at Runtime

| Parameter | Mutable | Method |
|-----------|---------|--------|
| Distance | No | Recreate collection |
| Vector size | No | Recreate collection |
| HNSW `m`, `ef_construct` | Yes | `updateCollection` |
| Quantization | Yes | `updateCollection` |
| Optimizer settings | Yes | `updateCollection` |
| On-disk flag | No | Set at creation |
| Multi-vector comparator | No | Recreate collection |
