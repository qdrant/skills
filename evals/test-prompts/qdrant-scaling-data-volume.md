---
id: qdrant-scaling-data-volume
skill_url: https://skills.qdrant.tech/qdrant-scaling/scaling-data-volume/SKILL.md
rubric:
  must:
    - Recognizes this as a global-search case (rules out tenant and time-window strategies given no partition)
    - Recommends exhausting vertical scaling first (more RAM, better disk, quantization, mmap)
    - Then moves to horizontal scaling (sharding across nodes) once vertical limits are reached
  bonus:
    - Notes the alternative strategies (tenant scaling, sliding time window) and why they don't apply here
    - References the ~100M-vectors-per-node rule of thumb as the vertical ceiling
  avoid:
    - Jumps straight to horizontal scaling / sharding before considering vertical headroom
---
Our collection grew from 40M to 220M vectors and is close to exhausting RAM and disk on a single node. Queries still need global search across all data, with no clean tenant or time partition. How should we think through the next data-volume scaling step?
