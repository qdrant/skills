---
id: qdrant-monitoring-debugging
skill_url: https://skills.qdrant.tech/qdrant-monitoring/debugging/SKILL.md
rubric:
  must:
    - Directs the user to check optimizer status first (post-bulk-import optimizations compete for resources)
    - Distinguishes resident memory (RSS/RSSAnon) from OS page cache (page cache filling RAM is normal)
    - Points to /metrics and /telemetry for per-collection memory / point-count breakdown
    - Links the post-import symptom to too many unmerged segments slowing search
  bonus:
    - Gives the rough memory estimate (num_vectors x dimensions x 4 bytes x 1.5) to set expectations
  avoid:
    - Concludes 'memory leak' from page cache filling available RAM
    - Advises config changes while the optimizer is still running
---
Our Qdrant nodes started OOMing after a nightly bulk import, and searches are slower even though traffic is unchanged. Grafana shows memory climbing and CPU spikes during indexing. Which metrics and endpoints should I check to tell whether this is normal cache/optimization activity or a real problem?
