# Common Runtime Errors

Error messages you will encounter and how to fix them.

## Connection Errors

### `ConnectionRefusedError: [Errno 111] Connection refused`

Qdrant is not running or wrong port.

```bash
# Start Qdrant
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

Python uses REST (port 6333) by default. Verify with `curl http://localhost:6333/healthz`.

### `TimeoutError` or `httpx.ReadTimeout`

Server is overloaded or network is slow.

```python
# Increase timeout
client = QdrantClient("localhost", port=6333, timeout=60)
```

Default timeout is 5 seconds. Bulk operations on large collections may need 30-60s.

## Collection Errors

### `ValueError: Collection 'X' not found`

Collection does not exist. Create it first.

```python
# Check if collection exists
collections = client.get_collections().collections
names = [c.name for c in collections]
if "my_col" not in names:
    client.create_collection("my_col", vectors_config=VectorParams(...))
```

### `ValueError: Wrong input: Vector dimension error: expected dim: 768, got 384`

Vector dimensions don't match collection config. Check your embedding model output size.

```python
# Verify collection config
info = client.get_collection("col")
print(info.config.params.vectors.size)  # expected dimensions
```

### `ValueError: Wrong input: Not existing vector name: dense`

Named vector not configured in collection. Check vector names.

```python
info = client.get_collection("col")
print(info.config.params.vectors)  # shows configured vector names
```

## Payload Errors

### `ValueError: Wrong input: Payload type mismatch`

Field was indexed as one type but you're filtering with another. A keyword index expects strings, not integers.

```python
# Wrong: filtering keyword field with integer
FieldCondition(key="status", match=MatchValue(value=1))

# Right: use string
FieldCondition(key="status", match=MatchValue(value="active"))
```

### `ValueError: Field 'X' has no text index`

Full-text search requires a text index on the field.

```python
client.create_payload_index("col", "description",
    field_schema=PayloadSchemaType.TEXT)
```

## Search Errors

### `AttributeError: 'QdrantClient' has no attribute 'search'`

Using removed method. `search()` was removed in qdrant-client 2.x.

```python
# Old (removed)
client.search("col", query_vector=vec)

# New
client.query_points("col", query=vec)
```

### `TypeError: query_points() got unexpected keyword argument 'query_vector'`

Parameter renamed. Use `query=` not `query_vector=`.

## Upload Errors

### `ValueError: Batch size too large`

Reduce batch size. Each batch is sent as a single request.

```python
client.upload_points("col", points, batch_size=256)  # smaller batches
```

### `grpc._channel._InactiveRpcError` (when using gRPC)

gRPC channel issues. Common with long-running uploads. Use `prefer_grpc=False` (REST) for reliability, or handle reconnection.

## Distance Errors

### Trying to change distance metric

Distance is immutable after collection creation. You must recreate.

```python
# Cannot update distance. Must delete and recreate.
client.delete_collection("col")
client.create_collection("col", vectors_config=VectorParams(
    size=768, distance=Distance.EUCLID))  # new distance
```
