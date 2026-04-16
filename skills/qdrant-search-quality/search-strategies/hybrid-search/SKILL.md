---
name: qdrant-hybrid-search
description: "Explains hybrid search in Qdrant. Use when someone asks 'how do I setup hybrid search?', 'how to combine keyword and semantic search?', 'sparse plus dense vectors?', 'missing keyword matches', 'how to combine results from multiple searches?' and 'combining multiple representations'"
---

# Hybrid Search in Qdrant

Hybrid search means running two or more different searches in parallel and combining their results into one. 

In Qdrant this is powered by the Query API via `prefetch`: each `prefetch` runs exactly one type of search independently, and the outer `query` combines results from parallel prefetches.  
Prefetches can be nested and searches can be multi-stage, all pipeline happening in one request through Query API. See [Universal Query API](https://search.qdrant.tech/md/course/essentials/day-5/universal-query-api/) for examples.

Identify the user's problem and pick building blocks:
- What can go into one prefetch, e.g. power one search, in [Search Types](search-types/SKILL.md)
- How to combine results of these searches (RRF, DBSF, FormulaQuery, reranking) in [Combining Searches](combining-searches/SKILL.md)

Based on what you've picked, test your approach:
1. Configure Qdrant collection with [named vectors](https://search.qdrant.tech/md/documentation/manage-data/vectors/?s=named-vectors), where each named vector usually corresponds to one representation (different embedding models or different vector types) of a data point.
2. Construct a hybrid search request with Query API from your building blocks. You can search independently among one type of vectors, with `prefetch` + `using`, like shown in examples in [Hybrid Queries documentation](https://search.qdrant.tech/md/documentation/search/hybrid-queries).
3. Evaluate hybrid search quality on real user data and provide user with improvements and tradeoffs (speed/resources).

## How Isolated Are Parallel Searches?

Use when: different tenants share one collection and you need to understand hybrid search isolation guarantees.

If user wants to isolate/share hybrid search pipelines between tenants, consider that:

- Indexes (sparse, payload and dense) and [IDF modifier](https://search.qdrant.tech/md/documentation/manage-data/indexing/?s=idf-modifier) for sparse vectors are computed independently **per shard**, not per **tenant**.
- Prefetch runs independently per shard to retrieve #limit results, so for collection-level prefetches if collection has several shards, Qdrant will always prefetch under the hood #limit * #shard results. Final results are merged based on scores.
- In nested prefetches (deeper than 1 level), methods described in "Combining Searches" will be done on a shard level first, then per-shards results once again will be merged based on scores.

## What NOT to Do

- Choose a hybrid search pattern based on "vibes" without any [hybrid search quality evaluation](https://search.qdrant.tech/md/articles/hybrid-search/?s=how-effective-is-your-search-system) in-place.
- Create too many named vectors without a need. An unfilled named vector takes as many resources as a filled one.