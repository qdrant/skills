---
id: qdrant-hybrid-search-prefetches
skill_url: https://skills.qdrant.tech/qdrant-search-quality/search-strategies/hybrid-search/search-types/SKILL.md
rubric:
  must:
    - Recommends adding a sparse vector for lexical/exact matching alongside the dense vector (payload filtering gives no ranking score)
    - Suggests BM25 as the baseline sparse option (built-in, server-side, works out-of-domain)
    - Flags that tokenization/stemming config critically affects exact matches on SKUs / part numbers
    - Addresses German content — BM25 must be configured per language; several learned options (BM42/miniCOIL/SPLADE FastEmbed) are English-only
  bonus:
    - Mentions named vectors must be configured at collection creation (can't be added later)
    - Notes alternatives (SPLADE++ term expansion, external bge-m3 for multilingual) with tradeoffs
  avoid:
    - Recommends a sparse model without evaluating quality/resources on the user's own data
    - Proposes payload filtering as the ranking solution for keyword relevance
---
Our pure vector search keeps missing exact matches on product SKUs and part numbers, and part of our catalog is in German. We want to add a keyword-style signal alongside the embeddings. Which kind of sparse/lexical representation should we use, and what do we need to watch out for given the SKUs and the non-English text?
