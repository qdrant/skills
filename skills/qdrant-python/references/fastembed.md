# FastEmbed Integration

FastEmbed is Qdrant's lightweight Python embedding library. Small, fast, and runs locally with no GPU required.

## Installation

```bash
pip install fastembed
# or with qdrant-client (includes fastembed)
pip install qdrant-client[fastembed]
```

## Quick Start

```python
from fastembed import TextEmbedding

model = TextEmbedding("BAAI/bge-small-en-v1.5")

documents = ["Hello world", "Vector databases are great"]
embeddings = list(model.embed(documents))
# embeddings[0].shape -> (384,)
```

## Available Models

| Model | Dimensions | Speed | Quality |
|-------|-----------|-------|---------|
| `BAAI/bge-small-en-v1.5` | 384 | Fast | Good |
| `BAAI/bge-base-en-v1.5` | 768 | Medium | Better |
| `BAAI/bge-large-en-v1.5` | 1024 | Slower | Best |
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | Fast | Good |
| `nomic-ai/nomic-embed-text-v1.5` | 768 | Medium | Better |

List all supported models:

```python
from fastembed import TextEmbedding
print(TextEmbedding.list_supported_models())
```

## Batch Encoding

```python
model = TextEmbedding("BAAI/bge-small-en-v1.5")

# embed() returns a generator, wrap in list() if you need all at once
documents = ["doc1", "doc2", "doc3", ...]
embeddings = list(model.embed(documents, batch_size=256))
```

## With Qdrant Client (Built-in Integration)

The qdrant-client has built-in FastEmbed support if you installed with `[fastembed]`:

```python
from qdrant_client import QdrantClient

client = QdrantClient("localhost", port=6333)

# Set default embedding model on the client
client.set_model("BAAI/bge-small-en-v1.5")

# Add documents directly (embedding happens automatically)
client.add("col", documents=["Hello world", "Vector search"], ids=[1, 2])

# Query with text (embedding happens automatically)
results = client.query("col", query_text="search query", limit=5)
```

## Manual Integration with upload_points

```python
from fastembed import TextEmbedding
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance

model = TextEmbedding("BAAI/bge-small-en-v1.5")
client = QdrantClient("localhost", port=6333)

# Create collection matching model dimensions
client.create_collection("docs", vectors_config=VectorParams(
    size=384,  # bge-small-en-v1.5 output dim
    distance=Distance.COSINE,
))

# Encode and upload
documents = ["doc1 text", "doc2 text", "doc3 text"]
embeddings = list(model.embed(documents))

points = [
    PointStruct(id=i, vector=emb.tolist(), payload={"text": doc})
    for i, (emb, doc) in enumerate(zip(embeddings, documents))
]

client.upload_points("docs", points, batch_size=256)
```

## Sparse Embeddings (for Hybrid Search)

```python
from fastembed import SparseTextEmbedding

sparse_model = SparseTextEmbedding("Qdrant/bm25")

documents = ["Hello world", "Vector databases"]
sparse_embeddings = list(sparse_model.embed(documents))

# Each sparse embedding has .indices and .values
for emb in sparse_embeddings:
    print(emb.indices, emb.values)
```

## Image Embeddings

```python
from fastembed import ImageEmbedding

model = ImageEmbedding("Qdrant/clip-ViT-B-32-vision")
embeddings = list(model.embed(["image1.jpg", "image2.png"]))
```

## Late Interaction (ColBERT)

```python
from fastembed import LateInteractionTextEmbedding

model = LateInteractionTextEmbedding("colbert-ir/colbertv2.0")
embeddings = list(model.embed(["document text"]))
# Returns token-level embeddings (matrix per document)
```

## Key Points

- Models are downloaded on first use and cached locally
- CPU-only by default (no GPU needed)
- ONNX runtime for fast inference
- Thread-safe for batch encoding
- `embed()` returns a generator for memory efficiency
- Works in AWS Lambda and other serverless environments
