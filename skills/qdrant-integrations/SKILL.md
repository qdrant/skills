---
name: qdrant-integrations
description: "Guidance for integrating Qdrant with LangChain, LlamaIndex, Haystack, Cognee, and Google ADK. Use when someone asks: 'integrate Qdrant with LangChain', 'use Qdrant with LlamaIndex', 'connect Haystack to Qdrant', 'set up Cognee with Qdrant', 'use Google ADK with Qdrant', or 'how do I configure Qdrant in my framework app'."
---

# Qdrant Integrations

Use this skill to pick the right integration package and configuration for common LLM/agent frameworks.

## Need a Fast Integration Starting Point

Use when: user has not chosen a framework-specific setup yet.

- Start from the Qdrant frameworks index and jump to the exact integration page [Framework integrations](https://qdrant.tech/documentation/frameworks/)
- Prefer the framework-specific Qdrant page over older blog posts for setup details [Framework integrations](https://qdrant.tech/documentation/frameworks/)

## LangChain App Needs Dense, Sparse, or Hybrid Retrieval

Use when: user asks for LangChain + Qdrant vector store setup.

- Install the partner package: `pip install langchain-qdrant` [LangChain](https://qdrant.tech/documentation/frameworks/langchain/)
- Use `QdrantVectorStore.from_texts` or `QdrantVectorStore.from_documents` for bootstrap [LangChain](https://qdrant.tech/documentation/frameworks/langchain/)
- Set `retrieval_mode` explicitly (`DENSE`, `SPARSE`, `HYBRID`) to match your retrieval strategy [LangChain](https://qdrant.tech/documentation/frameworks/langchain/)
- For sparse or hybrid retrieval, provide sparse embeddings (for example `FastEmbedSparse`) in addition to dense embeddings where required [LangChain](https://qdrant.tech/documentation/frameworks/langchain/)
- Starter command + snippet: [LangChain](commands/langchain.md) [LangChain docs](https://qdrant.tech/documentation/frameworks/langchain/)

## LlamaIndex Pipeline Needs Qdrant Vector Store

Use when: user asks for LlamaIndex indexing/retrieval with Qdrant.

- Install integration packages: `pip install llama-index llama-index-vector-stores-qdrant` [LlamaIndex](https://qdrant.tech/documentation/frameworks/llama-index/)
- Create a `QdrantClient` and pass it into `QdrantVectorStore` [LlamaIndex](https://qdrant.tech/documentation/frameworks/llama-index/)
- Build the index from that vector store (for example `VectorStoreIndex.from_vector_store`) [LlamaIndex](https://qdrant.tech/documentation/frameworks/llama-index/)
- Starter command + snippet: [LlamaIndex](commands/llamaindex.md) [LlamaIndex docs](https://qdrant.tech/documentation/frameworks/llama-index/)

## Haystack RAG Pipeline Needs a Qdrant Document Store

Use when: user is building Haystack pipelines and needs Qdrant persistence/search.

- Install the Qdrant Haystack package: `pip install qdrant-haystack` [Haystack](https://qdrant.tech/documentation/frameworks/haystack/)
- Use `QdrantDocumentStore` as the backing store for documents and vectors [Haystack](https://qdrant.tech/documentation/frameworks/haystack/)
- Apply advanced Qdrant collection/client options (including quantization config) through `QdrantDocumentStore` constructor settings [Haystack](https://qdrant.tech/documentation/frameworks/haystack/)
- Starter command + snippet: [Haystack](commands/haystack.md) [Haystack docs](https://qdrant.tech/documentation/frameworks/haystack/)

## Cognee Memory Graph Needs Qdrant as Vector Backend

Use when: user wants Cognee memory + graph workflows backed by Qdrant.

- Install adapter package: `pip install Cognee-community-vector-adapter-qdrant` [Cognee](https://qdrant.tech/documentation/frameworks/cognee/)
- Register/configure Cognee with `vector_db_provider=qdrant` and `vector_dataset_database_handler=qdrant` [Cognee](https://qdrant.tech/documentation/frameworks/cognee/)
- Set Qdrant connection values (`vector_db_url`, `vector_db_key`) in config or environment variables [Cognee](https://qdrant.tech/documentation/frameworks/cognee/)
- Starter command + snippet: [Cognee](commands/cognee.md) [Cognee docs](https://qdrant.tech/documentation/frameworks/cognee/)

## Google ADK Agent Needs Qdrant Tools

Use when: user wants ADK agents to store/retrieve knowledge via Qdrant.

- Install ADK: `pip install google-adk` [Google ADK](https://qdrant.tech/documentation/frameworks/google-adk/)
- Connect ADK to Qdrant via Qdrant MCP Server in `McpToolset` configuration [Google ADK](https://qdrant.tech/documentation/frameworks/google-adk/)
- Configure runtime variables like `QDRANT_URL` and `COLLECTION_NAME` for the MCP server process [Google ADK](https://qdrant.tech/documentation/frameworks/google-adk/)
- Starter command + snippet: [Google ADK](commands/google-adk.md) [Google ADK docs](https://qdrant.tech/documentation/frameworks/google-adk/)

## What NOT to Do

- Do not mix integration packages across frameworks (for example, `qdrant-haystack` in a LangChain setup)
- Do not set LangChain sparse/hybrid retrieval without configuring sparse embeddings
- Do not leave Qdrant URL, API key, or collection names implicit when moving from local to cloud
- Do not use generic framework docs as the primary source when a Qdrant integration page exists
