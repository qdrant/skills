---
id: qdrant-relevance-feedback
skill_url: https://skills.qdrant.tech/qdrant-search-quality/search-strategies/relevance-feedback/SKILL.md
rubric:
  must:
    - Identifies the Relevance Feedback (RF) API as the fit — it modifies the search process to surface docs outside the ANN pool, unlike reranking which only reorders
    - Explains RF uses a small set of scored seed documents (~5) plus a feedback model (cross-encoder / embedding / LLM scorer)
    - States formula weights must be calibrated/trained once per use case on real queries before use (random weights give arbitrary results)
    - Maps the 'beyond the top results' need to the recall-oriented pattern (two feedback-scoring rounds), noting the higher-latency tradeoff
  bonus:
    - Mentions the qdrant-relevance-feedback Python library for training/calibration (train on ~50-200 real queries)
    - Notes RF works only in dense vector space (not sparse) and feedback scores must be monotonic (higher = more relevant)
  avoid:
    - Presents RF as a drop-in needing no training, or just recommends a standard reranker over the existing pool
---
Our dense retriever is a bit weak and the truly relevant doc often sits just outside the top results. We were about to bolt a cross-encoder reranker onto a large candidate pool, but that's too expensive for our latency budget. Is there a way to use a little reranker signal to actually pull better documents into the results, instead of just reordering what we already fetched?
