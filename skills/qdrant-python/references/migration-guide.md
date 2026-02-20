# Migration Guide: Old API to New API

Complete mapping of deprecated `qdrant-client` methods to their current replacements.

## Search Methods

| Old (removed) | New | Notes |
|---------------|-----|-------|
| `client.search(collection, query_vector=vec)` | `client.query_points(collection, query=vec)` | Direct replacement |
| `client.search(collection, query_vector=("dense", vec))` | `client.query_points(collection, query=vec, using="dense")` | Named vectors |
| `client.search_batch(collection, requests)` | `client.query_batch_points(collection, requests)` | Batch search |
| `client.search_groups(collection, ...)` | `client.query_points_groups(collection, ...)` | Grouped search |

## Recommend Methods

| Old (removed) | New | Notes |
|---------------|-----|-------|
| `client.recommend(collection, positive=[id1], negative=[id2])` | `client.query_points(collection, query=RecommendQuery(positive=[id1], negative=[id2]))` | Use RecommendQuery |
| `client.recommend_batch(...)` | `client.query_batch_points(...)` with RecommendQuery | Batch recommend |
| `client.recommend_groups(...)` | `client.query_points_groups(...)` with RecommendQuery | Grouped recommend |

## Discovery Methods

| Old (removed) | New | Notes |
|---------------|-----|-------|
| `client.discover(collection, target=id, context=pairs)` | `client.query_points(collection, query=DiscoverQuery(target=id, context=pairs))` | Use DiscoverQuery |
| `client.discover_batch(...)` | `client.query_batch_points(...)` with DiscoverQuery | Batch discover |

## Parameter Mapping

| Old parameter | New parameter | On |
|--------------|---------------|-----|
| `query_vector` | `query` | `query_points` |
| `append_payload` | `with_payload` | `query_points` |
| `with_vectors` | `with_vectors` | Unchanged |
| `score_threshold` | `score_threshold` | Unchanged |
| `search_params` | `search_params` | Unchanged |

## Filter Parameter

The filter parameter name changed:

```python
# Old
client.search("col", query_vector=vec, query_filter=my_filter)

# New (same name, still query_filter)
client.query_points("col", query=vec, query_filter=my_filter)
```

## Hybrid Search Migration

```python
# Old: separate search calls + manual fusion
results_dense = client.search("col", query_vector=("dense", dense_vec))
results_sparse = client.search("col", query_vector=("sparse", sparse_vec))
# manual RRF...

# New: single query with prefetch
client.query_points("col",
    prefetch=[
        Prefetch(query=dense_vec, using="dense", limit=20),
        Prefetch(query=sparse_vec, using="sparse", limit=20),
    ],
    query=FusionQuery(fusion=Fusion.RRF),
    limit=10,
)
```

## Scroll (unchanged)

`client.scroll()` is unchanged. It was never deprecated.

## Point Operations (unchanged)

These methods have not changed:
- `client.upsert()`
- `client.upload_points()`
- `client.delete()`
- `client.set_payload()`
- `client.overwrite_payload()`
- `client.delete_payload()`
- `client.get_points()`

## Collection Operations (unchanged)

These methods have not changed:
- `client.create_collection()`
- `client.delete_collection()`
- `client.update_collection()`
- `client.get_collection()`
- `client.get_collections()`
