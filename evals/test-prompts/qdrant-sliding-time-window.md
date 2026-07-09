---
id: qdrant-sliding-time-window
skill_url: https://skills.qdrant.tech/qdrant-scaling/scaling-data-volume/sliding-time-window/SKILL.md
rubric:
  must:
    - Recommends shard rotation (user-defined sharding, one shard key per time period) as the preferred approach
    - Explains deleting a shard key reclaims resources instantly, vs tombstones from delete-by-filter
    - Identifies current delete-by-filter as the wrong tool at this volume (tombstones degrade search, async compaction, no instant disk reclaim)
  bonus:
    - Mentions pre-creating the next period's shard key before rotation to avoid write disruption
    - Mentions hot/cold tiering (older shard keys on cheaper/slower nodes) for the 90-180 day data
    - Notes collection rotation (alias swap) as the alternative when per-period config differs
  avoid:
    - Recommends continuing high-volume filter-and-delete as the primary retention mechanism
---
We index about 15M news articles and social posts per day, but search only needs the last 90 days to be fast. Older content can be slower or dropped after 180 days. Our current delete-by-filter cleanup causes long slowdowns. What retention design should we use?
