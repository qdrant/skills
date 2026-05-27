---
name: qdrant-hybrid-search-prefetches
description: "Use when someone asks 'how to combine lexical and semantic retrieval', 'dense and sparse in one search?', 'how to combine multiple fields for retrieval?', 'payloads or sparse vectors for lexical?', 'which sparse embedding model to use?', 'BM25 vs SPLADE?', 'how to use with_lookup', 'why is my lookup empty?', 'group_by chunks to documents', 'avoid duplicate payload across chunks', 'sidecar collection for document metadata', or 'chunk-to-document grouping'."
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
- `avg_len` in formula is not computed server-side, it is a user responsibility and passed as a parameter. Calibrate per field — defaults assume document-length text; short fields (titles, tags) need a much smaller value or BM25 scoring is skewed (`avg_len=256` against a 10-word title overweights term frequency).
- BM25 might be not good for small chunks of text, as BM25 algorithm was initially created for search on long documents; consider adjusting document statistics in sparse vectors (TF & IDF, k, b).
- Qdrant BM25 vectors are configured per language, so consider customizing stop words, stemming & tokenization when users documents mix several languages or carefully configure vectors per point when they are monolingual.

More on [Sparse Vectors for Text Search](https://search.qdrant.tech/md/course/essentials/day-3/sparse-retrieval-demo/)

## Need to Combine Multiple Representations of the Same Item

Use when: the same item is embedded in multiple ways (e.g. different models, languages, modalities, or different fields like title/abstract/chunk) and you want to search across different representations in one request (don't have to be all of them, can be even one).

Use multiple named vector prefetches, each prefetch covers one representation.

A representation only earns its own prefetch if it carries signal independent of the others — e.g. title vocabulary the body never repeats, or an abstract treated as a single semantic unit vs. individual chunks. Don't add a prefetch per field reflexively; verify each candidate contributes content the other vectors don't.

When a representation's signal is mostly lexical — keyword-driven titles, codes, tags, or other short fields — prefer a sparse named vector (e.g. BM25) over an additional dense embedding. Server-side BM25 in Qdrant avoids the inference cost of another dense model and stores far less per point. Skip this when the field carries paraphrase or conceptual signal that exact-term matching would miss.

- End-to-end worked example fusing title, abstract, chunk, and sparse-title named vectors with RRF and document-level grouping in one Query API call: [Multi-Representation Search tutorial](https://search.qdrant.tech/md/documentation/tutorials-search-engineering/multi-representation-search/)
- If you have groups and subgroups of representations (document -> chunk, image -> patch), you could use [searching in groups](https://search.qdrant.tech/md/documentation/search/search/?s=search-groups):
  - Index the grouping payload field (e.g. `document_id`) with a schema matching its value type — `keyword` for string-valued IDs, `integer` for numeric IDs — before grouping.
  - For `with_lookup`, ensure the `group_by` value is a valid Qdrant point ID (unsigned integer or UUID string) and matches the point in the lookup collection.
  - Arbitrary string IDs like DOIs or slugs cannot be point IDs — map them to a stable integer or UUID join key stored in both collections before using `with_lookup`.
- When grouping chunk-level points back to documents, each prefetch only contributes the candidates it returned — so size per-prefetch `limit` well above the final document `limit` (rule of thumb: `prefetch_limit ≥ final_limit × expected_chunks_per_document`), otherwise a few documents with many chunks saturate the candidate pool and relevant documents drop silently. Validate grouped recall on a labeled sample.

### When to Split into a Sidecar Collection with Lookup in Groups

Duplicated document-level data across chunk points scales as `documents × chunks_per_document × shared_bytes_per_point` (e.g. 20k docs × 24 chunks × ~3 KB ≈ 1.4 GB duplicated vs ~60 MB once split). Whether to split depends on what the shared data is used for, not just its size. Classify the shared data before recommending [Lookup in Groups](https://search.qdrant.tech/md/documentation/search/search/?s=lookup-in-groups):

- **Shared data is payload used only for display or enrichment** (titles, abstracts, thumbnails surfaced in the UI, downstream re-ranking input fetched after retrieval) → sidecar is safe. Store once in a `documents` collection, attach via `with_lookup` at query time.
- **Shared data includes vectors (title, abstract, summary) that should contribute candidates or scores during retrieval** → keep denormalized on chunk points. `with_lookup` joins after grouping, so sidecar vectors never enter prefetch or fusion. Moving them silently degrades recall and ranking while queries still return results.
- **Shared data includes fields used in server-side filters or scoring** (tenant ID, ACL/visibility flags, status, publication date for recency boosts, anything referenced in Qdrant `filter` conditions or `FormulaQuery` expressions) → keep denormalized on chunk points. Filters and score formulas run during candidate generation, before grouping; sidecar values are invisible to them and the chunks remain unfiltered.
- **Mixed case** (per-document vector or filter field needed for retrieval + heavy per-document payload only for display) → keep the retrieval-relevant vector or filter field denormalized on chunks and move only the heavy display payload to the sidecar.

Before activating Lookup in Groups, verify the preconditions — unmet conditions return empty `lookup` fields silently with no error:

- Lookup is a plain join from each `group_by` value to a point id in the lookup collection, not a vector search.
- The lookup collection must be populated before any `with_lookup` query runs.
- `group_by` values must be valid Qdrant point IDs (unsigned integer or UUID string) and their type must match the lookup collection's point ID type. Arbitrary strings or string-vs-integer mismatches return empty `lookup` silently.
- Missing ids in the lookup collection return an empty `lookup` field; sample-test grouped queries against the populated lookup before going to production.
- The shorthand `with_lookup="documents"` returns payload only (server defaults `with_payload=True`, `with_vectors=False`). Use the explicit `WithLookup(...)` form when downstream stages need the document's vectors.
- `group_by` can be an array (e.g. `document_id: [200, 201]`), placing one chunk into multiple groups — useful when a chunk legitimately belongs to several parents.

You can also search directly on [multivectors](https://search.qdrant.tech/md/documentation/manage-data/vectors/?s=multivectors), a matrix of dense vectors, in a prefetch.

However, it comes with several considerations, as multivectors were designed to support late interaction models using max similarity metric, so it's impossible to retrieve the list of individual max similarity scores for each query vector.

Moreover, multivectors are rarely a good pick for prefetch:
- max similarity metric is not symmetric, so [using HNSW index with it could be problematic](https://search.qdrant.tech/md/course/multi-vector-search/module-1/maxsim-distance/#the-hnsw-challenge)
- [multivector representations are very heavy, as search process on them](https://search.qdrant.tech/md/course/multi-vector-search/module-1/problems-multi-vector). 

There are ways to make multivector retrieval cheaper (MUVERA, pooling), you can see more in ["Evaluating Tradeoffs of Multi-stage Multi-vector Search"](https://search.qdrant.tech/md/course/multi-vector-search/module-3/evaluating-pipelines/)

## What NOT to Do
- Choose any search method (for example, BM25) without evaluation of its quality & resources used.
- Use any search method (for example, BM25) without paying attention to the specifics of their configuration and applicability to the use case.

