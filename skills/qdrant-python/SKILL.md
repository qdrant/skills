---
name: qdrant-python
description: "Best practices for the Qdrant Python SDK. Use when writing code that uses qdrant-client. Covers query_points, filtering, hybrid search, multi-tenancy, and common gotchas."
allowed-tools: Read Grep Glob
license: Apache-2.0
metadata:
  author: qdrant
  version: "1.0"
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
| Recommend (similar items) | `client.query_points(col, query=RecommendQuery(positive=[id1, id2], negative=[id3]))` |
| Discover (constrained explore) | `client.query_points(col, query=DiscoverQuery(target=id1, context=[ContextPair(positive=id2, negative=id3)]))` |
| Set payload | `client.set_payload(col, payload={"key": "new_val"}, points=[point_id])` |
| Overwrite payload | `client.overwrite_payload(col, payload={"key": "val"}, points=[point_id])` |
| Delete payload keys | `client.delete_payload(col, keys=["key1", "key2"], points=[point_id])` |
| Clear all payload | `client.clear_payload(col, points_selector=[point_id])` |
| Create snapshot | `client.create_snapshot(col)` returns snapshot info |
| List snapshots | `client.list_snapshots(col)` |
| Download snapshot | `client.download_snapshot(col, snapshot_name, path="snapshot.tar")` |
| Full storage snapshot | `client.create_full_snapshot()` |
| Create alias | `client.update_collection_aliases(change_aliases_operations=[CreateAliasOperation(create_alias=CreateAlias(collection_name="col", alias_name="alias"))])` |
| Switch alias | Delete old alias + create new in one `change_aliases_operations` call |
| Update collection | `client.update_collection(col, optimizer_config=OptimizersConfigDiff(indexing_threshold=20000))` |

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

## Recommend (Find Similar)

```python
from qdrant_client.models import RecommendQuery

client.query_points("products",
    query=RecommendQuery(positive=[1, 2], negative=[3]),
    limit=10)
```

## Discover (Constrained Exploration)

```python
from qdrant_client.models import DiscoverQuery, ContextPair

client.query_points("products",
    query=DiscoverQuery(
        target=42,
        context=[ContextPair(positive=1, negative=2)],
    ), limit=10)
```

## Payload Mutation

```python
# Set (merge new keys into existing payload)
client.set_payload("col", payload={"status": "reviewed"}, points=[1, 2, 3])

# Overwrite (replace entire payload)
client.overwrite_payload("col", payload={"status": "clean"}, points=[1])

# Delete specific keys
client.delete_payload("col", keys=["temp_field"], points=[1, 2])

# Clear all payload
client.clear_payload("col", points_selector=[1])
```

## Collection Aliases

```python
from qdrant_client.models import CreateAliasOperation, CreateAlias, DeleteAliasOperation, DeleteAlias

# Zero-downtime swap: build new collection, then swap alias
client.update_collection_aliases(
    change_aliases_operations=[
        DeleteAliasOperation(delete_alias=DeleteAlias(alias_name="production")),
        CreateAliasOperation(create_alias=CreateAlias(
            collection_name="products_v2", alias_name="production")),
    ]
)
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

## References

- `references/filtering.md`: Filter conditions (match, range, geo, nested, null)
- `references/migration-guide.md`: Old API to new API migration map
- `references/common-errors.md`: Runtime error messages and solutions
- `references/data-ingestion.md`: Batch upload, parallel workers, retry patterns
- `references/fastembed.md`: FastEmbed local embedding library integration
- `references/advanced-indexing.md`: HNSW tuning, quantization, ColBERT multi-vector config
