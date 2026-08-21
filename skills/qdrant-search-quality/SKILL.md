---
name: qdrant-search-quality
description: "Diagnoses and improves Qdrant search relevance. Use when someone reports 'search results are bad', 'wrong results', 'low precision', 'low recall', 'irrelevant matches', 'missing expected results', or asks 'how to improve search quality?', 'which embedding model?', 'should I use hybrid search?', 'should I use reranking?', 'how to measure retrieval quality?', 'build a golden set', 'ground truth dataset', or 'how to score recall@k?'. Also use when search quality degrades after quantization, model change, or data growth."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Search Quality

## Symptom to Sub-skill Map

| Symptom | Sub-skill |
|---|---|
| Search results are bad or irrelevant | [Diagnosis and Tuning](diagnosis/SKILL.md) |
| Low recall, expected results are missing | [Diagnosis and Tuning](diagnosis/SKILL.md) |
| Low precision, too many wrong matches | [Diagnosis and Tuning](diagnosis/SKILL.md) |
| Quality dropped after quantization or a model change | [Diagnosis and Tuning](diagnosis/SKILL.md) |
| Not sure if the model, the data, or Qdrant is at fault | [Diagnosis and Tuning](diagnosis/SKILL.md) |
| Want to measure recall or build a golden set | [Diagnosis and Tuning](diagnosis/SKILL.md) |
| Need to combine keyword and semantic search | [Search Strategies](search-strategies/SKILL.md) |
| Want hybrid search, reranking, or score fusion | [Search Strategies](search-strategies/SKILL.md) |
| Improving results with relevance feedback or recommendations | [Search Strategies](search-strategies/SKILL.md) |

First determine whether the problem is the embedding model, Qdrant configuration, or the query strategy. Most quality issues come from the model or data, not from Qdrant itself. If search quality is low, inspect how chunks are being passed to Qdrant before tuning any parameters. Splitting mid-sentence can drop quality 30-40%.

- Start by testing with exact search to isolate the problem [Search API](https://skills.qdrant.tech/md/documentation/search/search/?s=search-api)


## Diagnosis and Tuning

Isolate the source of quality issues, establish labeled baselines to measure recall and relevance, tune HNSW parameters, and choose the right embedding model. [Diagnosis and Tuning](diagnosis/SKILL.md)


## Search Strategies

Hybrid search, reranking, relevance feedback, and exploration APIs for improving result quality. [Search Strategies](search-strategies/SKILL.md)
