---
id: qdrant-scaling-qps
skill_url: https://skills.qdrant.tech/qdrant-scaling/scaling-qps/SKILL.md
rubric:
  must:
    - Recommends throughput tuning — fewer, larger segments (e.g. default_segment_number ~2)
    - Scales out horizontally with read replicas (replication_factor 2+, route reads to replicas)
    - Uses the batch search API to amortize per-request overhead
  bonus:
    - Enables quantization with always_ram to reduce disk IO under concurrent load
    - Reserves CPU for queries (optimizer_cpu_budget / update-throughput control) so indexing doesn't starve reads
  avoid:
    - Applies latency-oriented tuning (many small segments) — the opposite direction
    - Conflates this with single-query latency reduction or data-volume scaling
---
Our search service peaks at roughly 800 queries/sec today and we need to sustain ~3,000 QPS for a launch. Per-query latency is fine — we just can't hold the concurrent request rate and CPU pegs out. What's the path to higher throughput?
