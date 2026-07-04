# Qdrant Skills

Agent skills encoding deep Qdrant knowledge for coding agents.

## Available Skills

- [qdrant-clients-sdk](qdrant-clients-sdk/SKILL.md) — Client SDKs for Python, TypeScript, Rust, Go, .NET, and Java.
- [qdrant-deployment-options](qdrant-deployment-options/SKILL.md) — Choosing between local, Docker, self-hosted, Cloud, and embedded deployments.
- [qdrant-edge](qdrant-edge/SKILL.md) — Building on the embedded in-process shard: server sync, on-device BM25, snapshots, and what to reuse versus implement.
- [qdrant-model-migration](qdrant-model-migration/SKILL.md) — Switching embedding models without downtime.
- [qdrant-monitoring](qdrant-monitoring/SKILL.md) — Monitoring, observability, health checks, and debugging production issues.
  - [qdrant-monitoring-setup](qdrant-monitoring/setup/SKILL.md) — Setting up Prometheus, health probes, alerting, and log centralization.
  - [qdrant-monitoring-debugging](qdrant-monitoring/debugging/SKILL.md) — Diagnosing production issues from metrics and observability data.
- [qdrant-performance-optimization](qdrant-performance-optimization/SKILL.md) — Search speed, memory usage, and indexing performance tuning.
  - [qdrant-search-speed-optimization](qdrant-performance-optimization/search-speed-optimization/SKILL.md) — Diagnosing and fixing slow search and high query latency.
  - [qdrant-memory-usage-optimization](qdrant-performance-optimization/memory-usage-optimization/SKILL.md) — Diagnosing and reducing RAM usage and out-of-memory crashes.
  - [qdrant-indexing-performance-optimization](qdrant-performance-optimization/indexing-performance-optimization/SKILL.md) — Diagnosing and fixing slow ingestion and indexing.
- [qdrant-scaling](qdrant-scaling/SKILL.md) — Scaling decisions: data volume, QPS, latency, horizontal vs vertical.
  - [qdrant-scaling-data-volume](qdrant-scaling/scaling-data-volume/SKILL.md) — Scaling when data no longer fits or needs more storage.
  - [qdrant-scaling-qps](qdrant-scaling/scaling-qps/SKILL.md) — Increasing query throughput (QPS).
  - [qdrant-scaling-query-volume](qdrant-scaling/scaling-query-volume/SKILL.md) — Handling large result sets and scroll-heavy workloads.
  - [qdrant-minimize-latency](qdrant-scaling/minimize-latency/SKILL.md) — Reducing per-query latency and tail (p99) latency.
- [qdrant-search-quality](qdrant-search-quality/SKILL.md) — Diagnosing bad results, search strategies, hybrid search, and reranking.
  - [qdrant-search-quality-diagnosis](qdrant-search-quality/diagnosis/SKILL.md) — Diagnosing irrelevant, wrong, or missing results.
  - [qdrant-search-strategies](qdrant-search-quality/search-strategies/SKILL.md) — Choosing strategies: hybrid search, reranking, relevance feedback.
- [qdrant-version-upgrade](qdrant-version-upgrade/SKILL.md) — Safe upgrade paths, compatibility guarantees, and rolling upgrades.

Skills structure is hierarchical.
You can use search: https://skills.qdrant.tech/search?query=your+query+here