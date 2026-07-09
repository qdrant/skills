---
id: qdrant-minimize-latency
skill_url: https://skills.qdrant.tech/qdrant-scaling/minimize-latency/SKILL.md
rubric:
  must:
    - Increases segment count toward CPU core count (e.g. default_segment_number ~16) for lower per-query latency
    - Reduces hnsw_ef at query time to trade some recall for speed
    - Keeps HNSW and quantized vectors in RAM (always_ram=true)
  bonus:
    - Recommends local NVMe / avoiding network-attached storage
    - Limits background optimization CPU (optimizer_cpu_budget) or schedules indexing off-peak
  avoid:
    - Applies throughput tuning (fewer/larger segments) — the opposite direction from latency
    - Treats it as an incident to diagnose or recommends adding nodes for QPS
---
Our recommendation API does a single vector search per request and p99 has sat around 250ms since launch — product wants it under 60ms. Throughput isn't the issue; even at low traffic one query is slow, and the collection fits comfortably in RAM on a large node. What can we tune to make individual queries faster?
