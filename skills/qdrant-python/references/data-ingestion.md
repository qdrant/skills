# Data Ingestion Best Practices

Patterns for uploading data efficiently into Qdrant.

## Use `upload_points` for Bulk Inserts

Never call `upsert` in a loop. Use the batch upload method:

```python
from qdrant_client.models import PointStruct

points = [
    PointStruct(id=i, vector=vectors[i], payload=payloads[i])
    for i in range(len(vectors))
]

# Good: single call with batching
client.upload_points("col", points, batch_size=256)

# Bad: one-by-one upsert loop
for p in points:
    client.upsert("col", points=[p])  # extremely slow
```

## Optimal Batch Sizes

| Dataset size | Recommended batch_size | Notes |
|-------------|----------------------|-------|
| < 10k points | 256-512 | Default is fine |
| 10k-100k points | 256 | Balanced speed and memory |
| 100k-1M points | 128-256 | Monitor server memory |
| > 1M points | 64-128 | Smaller batches, parallel workers |

The right batch size depends on vector dimensions and payload size. Larger vectors need smaller batches to stay under gRPC/HTTP message limits.

## Parallel Upload

For large datasets, use multiple workers:

```python
import multiprocessing
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct

def upload_chunk(chunk):
    client = QdrantClient("localhost", port=6333)
    client.upload_points("col", chunk, batch_size=256)

# Split points into chunks
chunks = [points[i::4] for i in range(4)]

with multiprocessing.Pool(4) as pool:
    pool.map(upload_chunk, chunks)
```

Each worker needs its own client instance (connections are not thread-safe for upload).

## Create Indexes Before Upload

Always create payload indexes before bulk upload. Adding indexes after triggers a full re-index of existing data:

```python
# Step 1: Create collection
client.create_collection("col", vectors_config=VectorParams(size=768, distance=Distance.COSINE))

# Step 2: Create payload indexes BEFORE upload
client.create_payload_index("col", "category", field_schema=PayloadSchemaType.KEYWORD)
client.create_payload_index("col", "price", field_schema=PayloadSchemaType.FLOAT)
client.create_payload_index("col", "tenant_id", field_schema=PayloadSchemaType.KEYWORD, is_tenant=True)

# Step 3: Upload data
client.upload_points("col", points, batch_size=256)
```

## Write Ordering

For most use cases, default ordering (weak) is fine. Use strong ordering only when you need immediate consistency:

```python
from qdrant_client.models import WriteOrdering, WriteOrderingType

# Default (weak): fastest, eventually consistent
client.upsert("col", points)

# Strong: waits for WAL write on all replicas
client.upsert("col", points, ordering=WriteOrdering(type=WriteOrderingType.STRONG))
```

## Retry Pattern

Network errors during bulk upload are common. Wrap uploads with retry logic:

```python
import time

def upload_with_retry(client, collection, points, max_retries=3):
    for attempt in range(max_retries):
        try:
            client.upload_points(collection, points, batch_size=256)
            return
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            print(f"upload failed (attempt {attempt + 1}): {e}")
            time.sleep(2 ** attempt)
```

## Streaming Large Datasets

For datasets that don't fit in memory, use generators:

```python
def read_points(file_path):
    """Yield PointStruct one at a time from a large file."""
    with open(file_path) as f:
        for i, line in enumerate(f):
            data = json.loads(line)
            yield PointStruct(
                id=i,
                vector=data["vector"],
                payload=data["metadata"],
            )

# upload_points accepts iterables, not just lists
client.upload_points("col", read_points("data.jsonl"), batch_size=256)
```

## Disable Indexing During Bulk Upload

For very large imports (millions of points), temporarily disable indexing to speed up upload, then re-enable:

```python
from qdrant_client.models import OptimizersConfigDiff

# Disable indexing (set very high threshold)
client.update_collection("col",
    optimizer_config=OptimizersConfigDiff(indexing_threshold=0))

# Upload all data
client.upload_points("col", points, batch_size=256)

# Re-enable indexing (default threshold is 20000)
client.update_collection("col",
    optimizer_config=OptimizersConfigDiff(indexing_threshold=20000))
```
