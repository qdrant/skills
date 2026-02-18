---
name: qdrant-python
description: "Best practices for the Qdrant Python SDK. Use when writing code that uses qdrant-client. Covers query_points, filtering, hybrid search, multi-tenancy, and common gotchas."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant

You manage collections, insert points, and run vector searches against a Qdrant instance using `qdrant-client`.

## Decision Table

| Want to... | Do |
|-----------|-----|
| Create a collection | `client.create_collection(name, vectors_config=VectorParams(size=N, distance=Distance.COSINE))` |
| Insert points | `client.upsert(collection, points=[PointStruct(id, vector, payload)])` |
| Bulk insert | `client.upload_points(collection, points, batch_size=1000)` |
| Search by vector | `client.query_points(collection, query=vector, limit=10)` |
| Search with filter | Add `query_filter=Filter(must=[FieldCondition(...)])` to search |
| Hybrid search | Use `prefetch` with dense + sparse, fuse with `FusionQuery(fusion=Fusion.RRF)` |
| Diverse results (MMR) | `query=NearestQuery(nearest=emb, mmr=Mmr(diversity=0.5))` |
| Filtered search (Acorn) | Add `search_params=SearchParams(acorn=True)` with filters |
| Cloud inference | `query=Document(text="query", model="model-name")` |
| Scroll all points | `client.scroll(collection, limit=100)` returns `(points, next_offset)` |
| Create payload index | `client.create_payload_index(collection, field, schema_type=PayloadSchemaType.KEYWORD)` |
| Multi-tenant | One collection + `create_payload_index(field, is_tenant=True)` + filter per query |

## Search with Filters

```python
client.query_points("products",
    query=embedding,
    query_filter=Filter(must=[
        FieldCondition(key="category", match=MatchValue(value="electronics")),
    ]), limit=10)
```

## Hybrid Search (Dense + Sparse)

```python
client.query_points("docs",
    prefetch=[
        Prefetch(query=dense_emb, using="dense", limit=20),
        Prefetch(query=sparse_emb, using="sparse", limit=20),
    ],
    query=FusionQuery(fusion=Fusion.RRF), limit=10)
```

## Cloud Inference (No Local Model)

```python
client = QdrantClient(
    url="https://xyz.cloud.qdrant.io:6333",
    api_key=os.environ["QDRANT_API_KEY"],
    cloud_inference=True,
)

client.upsert("col", [PointStruct(
    id=1, payload={"topic": "cooking"},
    vector=Document(
        text="Chocolate chip cookie recipe",
        model="openrouter/thenlper/gte-base",
        options={"openrouter-api-key": "<key>"},
    ),
)])

client.query_points("col", query=Document(
    text="cookie recipe",
    model="openrouter/thenlper/gte-base",
    options={"openrouter-api-key": "<key>"},
))
```

## MMR (Diversity-Aware Results)

```python
client.query_points("col",
    query=models.NearestQuery(
        nearest=embedding,
        mmr=models.Mmr(diversity=0.5),
    ), limit=5)
```

## Gotchas

- **`query_points` not `search`**: All search variants are removed. Use `query_points`.
- **Never one collection per user**: Use `is_tenant=True` payload index.
- **Create payload indexes BEFORE bulk upload**: Adding after triggers full re-index.
- **BM25 requires `Modifier.IDF`**: Without it, sparse search quality is poor.
- **Prefetch limit > final limit**: Prefetch is the candidate pool.
- **Scroll offset is a cursor, not skip**: `next_offset` is a point ID.
- **Don't exact-match floats**: Use `Range(gte=19.98, lte=20.0)`.
- **Distance is immutable**: Delete and recreate to change it.
- **Vector size must match**: Every insert and query must match collection dims.
- **`upload_points` for bulk**: Don't call `upsert` in a loop for 10k+ points.
- **Acorn only with filters**: `acorn=True` adds overhead without filters.
- **Cloud inference needs `cloud_inference=True`** on client init.

## Read More

[How to Teach AI Agents to Use Qdrant Without Breaking Things](https://qdrant.tech/blog/qdrant-ai-coding-agents/)
