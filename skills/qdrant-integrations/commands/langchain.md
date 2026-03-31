# LangChain + Qdrant

Docs: [LangChain](https://qdrant.tech/documentation/frameworks/langchain/)

## Run

`python3 commands/langchain.py`

## Snippet

```python
from langchain_qdrant import FastEmbedSparse, QdrantVectorStore, RetrievalMode
from qdrant_client import QdrantClient, models
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings()
sparse_embeddings = FastEmbedSparse(model_name="Qdrant/bm25")

collection_name = "collection-name" # replace with your own
dense_vector_name = "dense"
sparse_vector_name = "sparse"

client = QdrantClient(
    url=QDRANT_URL,
    api_key=QDRANT_API_KEY
)
client.create_collection(
    collection_name = collection_name,
    vectors_config = {
        dense_vector_name : models.VectorParams(size = 1536,
                                     distance = models.Distance.COSINE
                                     )},
    sparse_vectors_config={
        sparse_vector_name: models.SparseVectorParams(
            index = models.SparseIndexParams(on_disk=False),
            modifier = models.Modifier.IDF,
        )
    })

db = QdrantVectorStore(
    client = client,
    collection_name = collection_name,
    embedding = dense_embeddings,
    sparse_embedding = sparse_embeddings,
    retrieval_mode = RetrievalMode.HYBRID,
    vector_name =dense_vector_name,
    sparse_vector_name = sparse_vector_name,
)
db.add_documents(documents=chunks) 

results = db.similarity_search("find relevant context")
print(results)
```
