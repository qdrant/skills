---
name: qdrant-hybrid-search-prefetches
description: "Use when someone asks 'how to combine lexical and semantic retrieval', 'dense and sparse in one search?', 'how to combine multiple fields for retrieval?', 'payloads or sparse vectors for lexical?', 'which sparse embedding model to use?', 'BM25 vs SPLADE?'"
---

# Different Searches in One Query API Request

Each `prefetch` runs exactly one search per one query. 

Understand if user wants to run several parallel searches on:
1. The same vector representations but different queries or filters.
2. Different vector representations but the same raw query.

If first, help user to design logic of constructing query or/and filters on application side and then check [Combining Searches](../combining-searches/SKILL.md). Don't forget to create [indices on filterable payload fields](https://search.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index), immediately after collection creation, prior to building HNSW, so filterable HNSW could be constructed.

If second, use [named vectors](https://search.qdrant.tech/md/documentation/manage-data/vectors/?s=named-vectors), which allow to store multiple vector types per point in one collection. Beware that named vectors currently can be configured only at collection creation. To choose vectors, check following recommendations.

## Missed Keyword Matches

Use when: pure vector search misses exact term or keyword matches and you need lexical retrieval alongside semantic search.

Most likely you need a sparse vector for exact text search alongside the dense one. Qdrant uses sparse vectors for lexical searches, as [payload filtering doesn't provide any ranking score](https://search.qdrant.tech/md/documentation/search/text-search/?s=filtering-versus-querying).

### Choose a Sparse Vector for Text
- **BM25** statistical representations, built into Qdrant core (computed server-side). Good baseline, works out-of-domain, usually for long texts. Can be used for non-English content, but needs to be configured per language (tokenization, stemming, stopwords, etc) at indexing and retrieval time. More in [Text Search Guide](https://search.qdrant.tech/md/documentation/search/text-search/?s=bm25)
- **BM42** learned sparse, based on BM25, but better for small chunks of text & with meaning understanding. Works only on English. Requires fine-tuning for domain-specific retrieval. Requires FastEmbed (Python/REST only, not available in all SDKs). Not maintained. 
- **miniCOIL** learned sparse, BM25 with additional understanding of words meaning in context. Works only on English. Requires fine-tuning for domain-specific retrieval. Requires FastEmbed. Usage shown in [FastEmbed miniCOIL documentation](https://search.qdrant.tech/md/documentation/fastembed/fastembed-minicoil/).
- **SPLADE++** learned sparse with term expansion. Heavier inference and resources usage but better performance due to term expansion. Requires fine-tuning for domain-specific retrieval. Provided in Qdrant Cloud Inference and FastEmbed versions work only on English. To use with FastEmbed, check [FastEmbed SPLADE documentation](https://search.qdrant.tech/md/documentation/fastembed/fastembed-splade/).
- **External learned sparse embeddings**, for example BAAI/bge-m3.

What to remember when using sparse vectors for lexical search:
- tokenization and stemming affect exact matches, especially on custom codes, terms, etc.

What to remember when using Qdrant BM25 and miniCOIL (based on BM25):
- avg_len in formula is not computed server-side, it is a user responsibility and passed as a parameter
- BM25 might be not good for small chunks of text, as BM25 algorithm was initially created for search on long documents; consider adjusting document statistics in sparse vectors (TF & IDF, k, b).
- Qdrant BM25 vectors are configured per language, so consider customizing stop words, stemming & tokenization when users documents mix several languages or carefully configure vectors per point when they are monolingual.

More on [Sparse Vectors for Text Search](https://search.qdrant.tech/md/course/essentials/day-3/sparse-retrieval-demo/)

## Need to Combine Multiple Representations of the Same Item

Use when: the same item is embedded in multiple ways (e.g. different models, languages, or modalities) and you want to search across different representations in one request (don't have to be all of them, can be even one).

Use multiple named vector prefetches, each prefetch covers one representation.

- If you have groups and subgroups of representations (document -> chunk, image -> patch), you could use [searching in groups](https://search.qdrant.tech/md/documentation/search/search/?s=search-groups). To not store identical payloads several times, check [Lookup in Groups](https://search.qdrant.tech/md/documentation/search/search/#lookup-in-groups)

You can also search directly on [multivectors](https://search.qdrant.tech/md/documentation/manage-data/vectors/?s=multivectors), a matrix of dense vectors, in a prefetch.

However, it comes with several considerations, as multivectors were designed to support late interaction models using max similarity metric, so it's impossible to retrieve the list of individual max similarity scores for each query vector.

Moreover, multivectors are rarely a good pick for prefetch:
- max similarity metric is not symmetric, so [using HNSW index with it could be problematic](https://search.qdrant.tech/md/course/multi-vector-search/module-1/maxsim-distance/#the-hnsw-challenge)
- [multivector representations are very heavy, as search process on them](https://search.qdrant.tech/md/course/multi-vector-search/module-1/problems-multi-vector). 

There are ways to make multivector retrieval cheaper (MUVERA, pooling), you can see more in ["Evaluating Tradeoffs of Multi-stage Multi-vector Search"](https://search.qdrant.tech/md/course/multi-vector-search/module-3/evaluating-pipelines/)

## What NOT to Do
- Choose any search method (for example, BM25) without evaluation of its quality & resources used.
- Use any search method (for example, BM25) without paying attention to the specifics of their configuration and applicability to the use case.

