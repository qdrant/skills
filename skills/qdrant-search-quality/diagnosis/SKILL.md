---
name: qdrant-search-quality-diagnosis
description: "Diagnoses Qdrant search quality issues. Use when someone reports 'results are bad', 'wrong results', 'not relevant results', 'missing matches', 'recall is low', 'approximate search worse than exact', 'which embedding model', 'should I fine-tune my embedding model', 'quality dropped after quantization', 'how to measure retrieval quality', 'build a golden set', 'ground truth dataset', 'how to score recall@k', or 'is my improvement real / statistically significant'. Also use when search quality degrades without obvious changes."
---

# How to Diagnose Bad Search Quality

Before diagnosing or evaluating search quality, establish two different ground truths: a labeled query set measures whether the results are the right ones; exact KNN measures whether ANN finds what brute force would (no labels needed). The first diagnoses relevance, the second diagnoses the index.

## Need a Labeled Baseline to Score Quality or Validate a Gain

Use when: user has no golden set, asks "how do I know if my search is good?", or needs to gate releases on a retrieval metric. Every fix in the sections below should be validated this way.

- Pick the metric by usage: `Recall@k` for RAG, `MRR`/`Hits@1` for single-answer, `NDCG@k` for re-ranking [Choosing the metric](https://skills.qdrant.tech/md/documentation/search-evaluation/retrieval-relevance/?s=choosing-the-right-metric)
- Build a labeled query set (human, log-based, or LLM-synthetic) and score retrieval with `ranx` [Measuring Retrieval Relevance](https://skills.qdrant.tech/md/documentation/search-evaluation/retrieval-relevance/)
- When tuning and evaluating search quality, set a minimum target gain, then make sure your labeled query set is large enough to measure it reliably. Quantify the uncertainty around a measured gain with a confidence interval (e.g. bootstrap the per-query gains, 95%): if it includes zero, the improvement is inconclusive and may be due to query-to-query variation. Adding labeled queries narrows the interval; how many you need depends on the size of the gain you are targeting and on query-to-query variation, not on collection size [Before tuning a collection](https://skills.qdrant.tech/md/documentation/search-tuning/before-tuning-a-qdrant-collection/?s=make-sure-your-labels-can-detect-a-gain)
- If you use the labeled queries to tune or select a configuration, evaluate the final choice on held-out queries. A gain that doesn't survive the held-out evaluation isn't reliable evidence of an improvement.
- For full RAG pipelines, also score generation with Ragas and use the retrieval-vs-generation 2x2 to isolate regressions [Pipeline Output Quality](https://skills.qdrant.tech/md/documentation/search-evaluation/pipeline-output-quality/)
- Gate CI on a per-metric threshold to catch regressions from embedding-model swaps, prompt changes, or index config changes

## Don't Know What's Wrong Yet

Use when: results are irrelevant or missing expected matches and you need to isolate the cause.

- For a no-code quick check, use the Web UI's ANN Recall tab to compare approximate vs exact `recall@k` [Web UI ANN Recall](https://skills.qdrant.tech/md/documentation/tutorials-search-engineering/ann-recall/?s=measure-ann-recall-with-the-web-ui)
- For the same comparison in code (CI gating, regression tests), run each query twice: once approximate, once with `exact=true`. Compute `recall@k` from the overlap [ANN recall in CI](https://skills.qdrant.tech/md/documentation/tutorials-search-engineering/ann-recall/?s=automate-in-ci-with-python)
- Target >95% `recall@k` in production. Exact search bad = model, data, or search pipeline problem. Exact good, approximate bad = tune HNSW.
- Match the embedding model to your data: the context window should fit your chunk length with room for special tokens, the model must cover every language in your corpus, and its training domain should resemble yours (e.g. a code-trained model for code) [How to choose an embedding model](https://skills.qdrant.tech/md/documentation/search-patterns/choose-embedding-model/)
- Make sure documents are properly chunked; splitting chunks mid-sentence alone can drop quality by 30-40%
- Check if quantization degrades quality (compare with and without)
- Check if filters are too restrictive (then you might need to use ACORN)
- If duplicate results from chunked documents, use Grouping API to deduplicate [Grouping](https://skills.qdrant.tech/md/documentation/search/search/?s=grouping-api)

Payload filtering and sparse vector search are different things. Metadata (dates, categories, tags) goes in payload for filtering. Text content goes in sparse vectors for search.

## Approximate Search Worse Than Exact

Use when: exact search returns good results but HNSW approximation misses them.

- `hnsw_ef` controls ANN search breadth; increase it while recall is still climbing, stop at the lowest value that hits your recall target inside your latency budget [Search params](https://skills.qdrant.tech/md/documentation/ops-optimization/optimize/?s=fine-tuning-search-parameters) [Raise `hnsw_ef` only when recall is still climbing](https://skills.qdrant.tech/md/documentation/search-tuning/candidate-depth/?s=raise-hnsw-ef-only-when-recall-is-still-climbing)
- Increase `ef_construct` (200+ for high quality) [HNSW config](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=vector-index)
- Increase `m` (16 default, 32 for high recall) [HNSW config](https://skills.qdrant.tech/md/documentation/manage-data/indexing/?s=vector-index)
- Enable oversampling + rescore with quantization [Search with quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/?s=searching-with-quantization)
- ACORN for filtered queries (v1.16+) [ACORN](https://skills.qdrant.tech/md/documentation/search/search/?s=acorn-search-algorithm)

Binary quantization requires rescore. Without it, quality loss is severe. Use oversampling to recover recall: the docs report 0.98 recall with 2x oversampling on 4096-dimensional and 4x on 1536-dimensional embeddings, so start around 2-4x and tune on your data. Always test quantization impact on your data before production. [Quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/)

## Wrong Embedding Model

Use when: exact search also returns bad results.

- Check [Qdrant team recommendations on how to choose an embedding model](https://skills.qdrant.tech/md/documentation/search-patterns/choose-embedding-model/).

- Test top 3 MTEB models on 100-1000 sample queries [Hosted Qdrant inference](https://skills.qdrant.tech/md/documentation/inference/). Score them against a labeled set to compare apples to apples [Measuring Retrieval Relevance](https://skills.qdrant.tech/md/documentation/search-evaluation/retrieval-relevance/).

- If your data is strongly hierarchical (taxonomies, product catalogs, part-whole relationships), consider hyperbolic (Poincaré) embeddings. They capture tree structure in far fewer dimensions than flat ones. In Qdrant, use Euclidean HNSW to pull a candidate set from the original Poincaré coordinates, then a Formula Query to rescore with the real hyperbolic distance. [How to serve hyperbolic embeddings with Qdrant](https://skills.qdrant.tech/md/articles/hyperbolic-embeddings-qdrant/).

- Consider fine-tuning an embedding model for your specific use case only after trying better-suited models and retrieval/pipeline tuning and confirming that the embedding model remains the bottleneck. Fine-tuning is most useful when general-purpose embeddings fail to capture important domain- or task-specific distinctions and you have good labeled query-document pairs. Fine-tuning requires re-embedding and re-indexing the collection [Model migration](../../qdrant-model-migration/SKILL.md).

## Unoptimized Search Pipeline

Use when: exact search also returns bad results and model choice is confirmed by user.

- Optimize search according to the advanced [search-strategies skill](../search-strategies/SKILL.md)
- Check candidate depth: if your retrieval pipeline includes a first-stage retriever that feeds a reranker or fusion stage, test whether increasing the prefetch limit improves your quality metric. A downstream ranker cannot recover relevant documents that never enter its candidate set. For hybrid search, start around `limit=100-200` and test larger values against your labeled queries [Candidate depth](https://skills.qdrant.tech/md/documentation/search-tuning/candidate-depth/?s=more-candidates-can-raise-the-best-possible-score)

## What NOT to Do

- Tune Qdrant before verifying the model is right for the task (most quality issues are model issues)
- Use binary quantization without rescore (severe quality loss)
- Set `hnsw_ef` lower than results requested (guaranteed bad recall)
- Skip payload indexes on filtered fields then blame quality (HNSW can't traverse filtered-out nodes, and filterable HNSW is built only if payload indexes were set up prior)
- Deploy without baseline recall or other search relevance metrics (no way to measure regressions)
- Compare two configs on a query set too small to resolve the difference between them (the result is noise, not evidence)
- Confuse payload filtering with sparse vector search (different things, different config)
