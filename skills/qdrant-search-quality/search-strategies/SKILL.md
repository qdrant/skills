---
name: qdrant-search-strategies
description: "Guides Qdrant search strategy selection. Use when someone asks 'should I use hybrid search?', 'BM25 or sparse vectors?', 'how to rerank?', 'results too similar', 'need diversity', 'MMR', 'relevance feedback', 'recommendation API', 'discovery API', 'ColBERT reranking', or 'missing keyword matches'. Also use when initial retrieval quality is acceptable but result ordering needs improvement."
---

# How to Improve Search Results with Advanced Strategies

These strategies complement basic vector search. Use them after confirming the embedding model and HNSW config are correct. If exact search returns bad results, fix the model first.


## Missing Obvious Keyword Matches

Use when: pure vector search misses results that contain obvious keyword matches.

Use hybrid when: domain terminology not in embedding training data, exact keyword matching critical (brand names, SKUs), acronyms common. Skip when: pure semantic queries, all data in training set, latency budget very tight.

- Dense + sparse with `prefetch` and fusion [Hybrid search](https://qdrant.tech/documentation/concepts/hybrid-queries/#hybrid-search)
- Prefer learned sparse (Splade, GTE) over raw BM25
- RRF: good default, supports weighted (v1.17+) [RRF](https://qdrant.tech/documentation/concepts/hybrid-queries/#reciprocal-rank-fusion-rrf)
- DBSF with asymmetric limits (sparse_limit=250, dense_limit=100) can outperform RRF for technical docs [DBSF](https://qdrant.tech/documentation/concepts/hybrid-queries/#distribution-based-score-fusion-dbsf)

For non-English languages, sparse BM25 without stop-word removal produces severely degraded results. Pre-process text before generating sparse vectors.


## Right Documents Found But Wrong Order

Use when: good recall but poor precision (right docs in top-100, not top-10).

- Cross-encoder rerankers via FastEmbed [Rerankers](https://qdrant.tech/documentation/fastembed/fastembed-rerankers/)
- ColBERT reranking can promote documents from mid-list to #1. Does not require GPU at query time. [Multi-stage](https://qdrant.tech/documentation/concepts/hybrid-queries/#multi-stage-queries)


## Results Too Similar

Use when: top results are redundant, near-duplicates, or lack diversity. Common in dense content domains (academic papers, product catalogs).

- Use MMR (v1.15+) as a query parameter with `diversity` to balance relevance and diversity [MMR](https://qdrant.tech/documentation/search/search-relevance/#maximal-marginal-relevance-mmr)
- Start with `diversity=0.5`, lower for more precision, higher for more exploration
- MMR is slower than standard search. Only use when redundancy is an actual problem.


## Results Don't Improve Between Iterations

Use when: you have a retrieval pipeline in place but results aren't getting better across search iterations.

- Use Relevance Feedback Query (v1.17+) to adjust retrieval based on relevance scores [Relevance Feedback](https://qdrant.tech/documentation/concepts/search-relevance/#relevance-feedback)
- Customize strategy parameters for your data with [qdrant-relevance-feedback package](https://pypi.org/project/qdrant-relevance-feedback/)
- Verify it actually helps with the built-in evaluator before deploying
- End-to-end tutorial [Using Relevance Feedback](https://qdrant.tech/documentation/tutorials-search-engineering/using-relevance-feedback/)


## Know What Good Results Look Like But Can't Get Them

Use when: you can provide positive and negative example points but don't have a feedback model.

- Recommendation API: positive/negative examples to find similar vectors [Recommendation API](https://qdrant.tech/documentation/concepts/explore/#recommendation-api)
  - Best score strategy: better for diverse examples, supports negative-only [Best score](https://qdrant.tech/documentation/concepts/explore/#best-score-strategy)
- Discovery API: context pairs to constrain search regions without a target [Discovery](https://qdrant.tech/documentation/concepts/explore/#discovery-api)


## What NOT to Do

- Use hybrid search before verifying pure vector quality (adds complexity, may mask model issues)
- Use BM25 on non-English text without stop-word removal (severely degraded results)
- Skip evaluation when adding relevance feedback (measure that it actually helps)
- Confuse Relevance Feedback Query with Recommendation API (different mechanisms, different use cases)
- Rerank without oversampling (if you only retrieve 10 candidates, reranking 10 items is pointless)
