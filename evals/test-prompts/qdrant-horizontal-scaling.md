---
id: qdrant-horizontal-scaling
skill_url: https://skills.qdrant.tech/qdrant-scaling/scaling-data-volume/horizontal-scaling/SKILL.md
rubric:
  must:
    - Recommends a cluster of at least 3 nodes (consensus + tolerate losing 1 node without downtime)
    - Uses replication_factor 2+ for fault tolerance and zero-downtime scaling/maintenance
    - Picks a shard count that is a multiple of node count, sized for distribution (e.g. ~6-12 shards for 3-6 nodes)
    - Over-provisions shards up front because resharding is expensive (and unavailable on self-hosted)
  bonus:
    - Uses the ~100M-vectors-per-node guideline to size node count for ~700M vectors
    - Mentions shard move API or migrating to a new cluster to rebalance instead of resharding
  avoid:
    - Uses replication_factor 1 in production where fault tolerance is required
    - Chooses a shard count that is not a multiple of node count (uneven distribution)
---
We're already on the largest practical node size and need to move a 700M-vector collection to a multi-node Qdrant deployment. We need fault tolerance, predictable shard distribution, and a plan for adding nodes later. How many nodes, shards, and replicas should we start with?
