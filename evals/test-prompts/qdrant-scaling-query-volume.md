---
id: qdrant-scaling-query-volume
skill_url: https://skills.qdrant.tech/qdrant-scaling/scaling-query-volume/SKILL.md
rubric:
  must:
    - Recognizes that with >1 shard, auto-sharding, a large limit (2000 ≥ 128), and a non-exact query, Qdrant already applies per-shard subsampling automatically — it is not making every shard return all 2000, so the assumed inefficiency isn't what's happening, and there is no feature to 'enable'.
    - Explains the mechanism and its tradeoff — each shard returns a smaller Poisson-computed limit that's then merged, accepting a tiny chance of slightly incomplete results (comparable to HNSW approximation) for far less inter-shard transfer.
    - Attributes the residual heaviness vs top-10 to the intrinsic cost of a large result set (scoring/merging plus hydrating and transferring ~2000 points), which subsampling does not remove; and notes that forcing exact=true would disable subsampling and cause the full cross-shard transfer they want to avoid.
  bonus:
    - States the activation conditions as reference (>1 shard, auto-sharding, limit+offset ≥ 128, non-exact).
    - Cites the precision detail — 1.2x safety factor + 99.9% Poisson threshold keep the error rate very low.
  avoid:
    - Presents per-shard subsampling as something the user must enable, configure, or tune (it's automatic).
    - Misdiagnoses this as a QPS/throughput problem or recommends generic horizontal scaling.
---
We run a query that pulls the top 2,000 matches at a time across a collection auto-sharded over 10 shards, and it's surprisingly heavy and slow compared to our usual top-10 searches. Is there a smarter way for Qdrant to handle these large-result queries without every shard shipping back everything?
