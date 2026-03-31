# LlamaIndex + Qdrant

Docs: [LlamaIndex](https://qdrant.tech/documentation/frameworks/llama-index/)

## Run

`python3 commands/llamaindex.py`

## Snippet

```python
import qdrant_client
from llama_index.core.indices.vector_store.base import VectorStoreIndex
from llama_index.vector_stores.qdrant import QdrantVectorStore

client = qdrant_client.QdrantClient(
    "<qdrant-url>",
    api_key="<qdrant-api-key>",
)

vector_store = QdrantVectorStore(client=client, collection_name="documents")
index = VectorStoreIndex.from_vector_store(vector_store=vector_store)
```
