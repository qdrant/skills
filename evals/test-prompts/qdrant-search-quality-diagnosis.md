---
id: qdrant-search-quality-diagnosis
skill_url: https://skills.qdrant.tech/qdrant-search-quality/diagnosis/SKILL.md
rubric:
  must:
    - Establishes a baseline by comparing approximate (HNSW) vs exact (exact=true) search to compute recall@k
    - Uses the exact-vs-approx split to localize — exact bad => model/pipeline; exact good but approx bad => tune HNSW
    - Isolates the recently enabled quantization by measuring quality with and without it
    - Builds a labeled/golden query set (human, log-based, or LLM-synthetic) and scores a metric like recall@k (e.g. via ranx)
  bonus:
    - Mentions the Web UI ANN Recall tab for a no-code check and CI gating on a metric threshold
    - Notes binary quantization needs oversampling + rescore or quality drops severely
  avoid:
    - Starts tuning HNSW/quantization params before verifying the embedding model and measuring a baseline
---
Users keep saying our semantic search "misses obvious documents." We don't have any ground-truth set, we recently turned on quantization, and we can't tell whether it's the embedding model, the index, or the quantization. How do we figure out where the quality is leaking and actually put a number on it?
