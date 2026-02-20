---
name: qdrant-typescript
description: "Best practices for the Qdrant TypeScript/JavaScript SDK (@qdrant/js-client-rest). Use when writing TS/JS code that uses Qdrant. Covers query, filtering, hybrid search, multi-tenancy, and common gotchas."
allowed-tools: Read Grep Glob
license: Apache-2.0
metadata:
  author: qdrant
  version: "1.0"
---

# Qdrant TypeScript/JavaScript Client

You interact with Qdrant over REST using `@qdrant/js-client-rest`.

## Setup

```bash
pnpm i @qdrant/js-client-rest
```

```typescript
import { QdrantClient } from '@qdrant/js-client-rest';

// Local
const client = new QdrantClient({ url: 'http://127.0.0.1:6333' });

// Cloud
const client = new QdrantClient({
    url: 'https://xyz.cloud.qdrant.io',
    apiKey: process.env.QDRANT_API_KEY,
});
```

## Decision Table

| Want to... | Do |
|-----------|-----|
| Create a collection | `client.createCollection('col', { vectors: { size: 768, distance: 'Cosine' } })` |
| Upsert points | `client.upsert('col', { points: [{ id: 1, vector: [...], payload: {...} }] })` |
| Search (modern) | `client.query('col', { query: vector, limit: 10 })` |
| Search with filter | Add `filter: { must: [{ key: 'field', match: { value: 'x' } }] }` |
| Hybrid search (RRF) | Use `prefetch` array with dense + sparse, `query: { fusion: 'rrf' }` |
| MMR diversity | `query: { nearest: vector, mmr: { diversity: 0.5 } }` |
| Scroll all points | `client.scroll('col', { limit: 100 })` returns `{ points, next_page_offset }` |
| Create payload index | `client.createPayloadIndex('col', { field_name: 'f', field_schema: 'keyword' })` |
| Multi-tenant | `field_schema: { type: 'keyword', is_tenant: true }` + filter per query |
| Named vectors | `vectors: { image: { size: 4, distance: 'Dot' }, text: { size: 8, distance: 'Cosine' } }` |
| Recommend | `client.query('col', { query: { recommend: { positive: [1, 2], negative: [3] } }, limit: 10 })` |
| Discover | `client.query('col', { query: { discover: { target: 1, context: [{ positive: 2, negative: 3 }] } }, limit: 10 })` |
| Set payload | `client.setPayload('col', { payload: { key: 'val' }, points: [1, 2] })` |
| Overwrite payload | `client.overwritePayload('col', { payload: { key: 'val' }, points: [1] })` |
| Delete payload keys | `client.deletePayload('col', { keys: ['key1'], points: [1] })` |
| Clear payload | `client.clearPayload('col', { points: [1] })` |
| Create snapshot | `client.createSnapshot('col')` |
| List snapshots | `client.listSnapshots('col')` |
| Create alias | `client.updateCollectionAliases({ actions: [{ create_alias: { collection_name: 'col', alias_name: 'alias' } }] })` |
| Switch alias | Combine `delete_alias` + `create_alias` in one `actions` array |
| Update collection | `client.updateCollection('col', { optimizers_config: { indexing_threshold: 20000 } })` |

## Query with Filter

```typescript
client.query('my_collection', {
    query: [0.2, 0.1, 0.9, 0.7],
    filter: {
        must: [{ key: 'category', match: { value: 'electronics' } }],
    },
    with_payload: true,
    limit: 10,
});
```

## Hybrid Search (Dense + Sparse with RRF)

```typescript
client.query('my_collection', {
    prefetch: [
        {
            query: { values: [0.22, 0.8], indices: [1, 42] },
            using: 'sparse',
            limit: 20,
        },
        {
            query: [0.01, 0.45, 0.67],
            using: 'dense',
            limit: 20,
        },
    ],
    query: { fusion: 'rrf' },
    limit: 10,
});
```

## Named Vectors

```typescript
// Create
client.createCollection('col', {
    vectors: {
        image: { size: 4, distance: 'Dot' },
        text: { size: 8, distance: 'Cosine' },
    },
    sparse_vectors: { text_sparse: {} },
});

// Upsert
client.upsert('col', {
    points: [{
        id: 1,
        vector: {
            image: [0.9, 0.1, 0.1, 0.2],
            text: [0.4, 0.7, 0.1, 0.8, 0.1, 0.1, 0.9, 0.2],
            text_sparse: { indices: [6, 7], values: [1.0, 2.0] },
        },
    }],
});

// Query specific vector
client.query('col', { query: [0.2, 0.1, 0.9], using: 'image', limit: 10 });
```

## Filtering (Plain Objects)

```typescript
// Match exact
{ key: 'city', match: { value: 'Berlin' } }

// Match any (IN)
{ key: 'color', match: { any: ['red', 'blue'] } }

// Match except (NOT IN)
{ key: 'color', match: { except: ['black'] } }

// Range
{ key: 'price', range: { gte: 10.0, lte: 100.0 } }

// Full-text (requires text index)
{ key: 'description', match: { text: 'vector database' } }

// Geo radius
{ key: 'location', geo_radius: { center: { lat: 52.52, lon: 13.40 }, radius: 1000.0 } }

// Nested object
{ nested: { key: 'reviews', filter: { must: [{ key: 'score', range: { gte: 4 } }] } } }

// Null / empty checks
{ is_null: { key: 'email' } }
{ is_empty: { key: 'tags' } }

// Has ID
{ has_id: [1, 3, 5] }
```

## Multi-Tenancy

```typescript
// Create tenant index
client.createPayloadIndex('col', {
    field_name: 'group_id',
    field_schema: { type: 'keyword', is_tenant: true },
});

// Query with tenant filter
client.query('col', {
    query: [0.1, 0.1, 0.9],
    filter: { must: [{ key: 'group_id', match: { value: 'user_1' } }] },
    limit: 10,
});
```

## Recommend (Find Similar)

```typescript
client.query('products', {
    query: { recommend: { positive: [1, 2], negative: [3] } },
    limit: 10,
});
```

## Discover (Constrained Exploration)

```typescript
client.query('products', {
    query: { discover: { target: 42, context: [{ positive: 1, negative: 2 }] } },
    limit: 10,
});
```

## Payload Mutation

```typescript
// Set (merge keys)
client.setPayload('col', { payload: { status: 'reviewed' }, points: [1, 2, 3] });

// Overwrite (replace entire payload)
client.overwritePayload('col', { payload: { status: 'clean' }, points: [1] });

// Delete specific keys
client.deletePayload('col', { keys: ['temp_field'], points: [1, 2] });

// Clear all payload
client.clearPayload('col', { points: [1] });
```

## Collection Aliases

```typescript
// Zero-downtime swap
client.updateCollectionAliases({
    actions: [
        { delete_alias: { alias_name: 'production' } },
        { create_alias: { collection_name: 'products_v2', alias_name: 'production' } },
    ],
});
```

## Gotchas

- **`search()` still exists but prefer `query()`**: Unlike Python where `search` was removed, the JS client has both. `query()` is the modern unified API.
- **`query()` not `query_points()`**: The method is just `query`, not `query_points` like Python.
- **No model classes**: Filters are plain JS objects, not `Filter(must=[FieldCondition(...)])`. No imports needed for conditions.
- **No `upload_points`**: Only `upsert()` exists. Batch manually for large uploads.
- **Distance values are strings**: `'Cosine'`, `'Euclid'`, `'Dot'`, `'Manhattan'` (not enums).
- **REST only (primary client)**: Uses port 6333 (HTTP), not 6334 (gRPC). There is a separate `@qdrant/js-client-grpc` package.
- **`upsert` `wait` defaults to `true`**: Writes are synchronous by default.
- **Scroll returns an object**: `{ points, next_page_offset }`, not a tuple like Python.
- **`prefetch` can be object or array**: Single object for pipeline re-scoring, array for fusion of multiple retrievals.
- **Constructor rejects `url` + `host` together**: Provide one or the other, never both.
- **No `cloud_inference` constructor option**: Cloud inference config differs from Python.
- **Vector size must match**: Every upsert and query must match collection dimensions.
- **Distance is immutable**: Delete and recreate collection to change it.
- **Never one collection per user**: Use `is_tenant: true` payload index.

## Read More

- [npm: @qdrant/js-client-rest](https://www.npmjs.com/package/@qdrant/js-client-rest)
- [GitHub: qdrant/qdrant-js](https://github.com/qdrant/qdrant-js)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
