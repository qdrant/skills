# Haystack + Qdrant

Docs: [Haystack](https://qdrant.tech/documentation/frameworks/haystack/)

## Run

`python3 commands/haystack.py`

## Snippet

```python
from qdrant_haystack.document_stores import QdrantDocumentStore
from qdrant_client import models

document_store = QdrantDocumentStore(
    ":memory:",
    index="Document",
    embedding_dim=512,
    recreate_index=True,
    quantization_config=models.ScalarQuantization(
        scalar=models.ScalarQuantizationConfig(
            type=models.ScalarType.INT8,
            quantile=0.99,
            always_ram=True,
        ),
    ),
)
```
