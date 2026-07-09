---
id: qdrant-hybrid-search
skill_url: https://skills.qdrant.tech/qdrant-search-quality/search-strategies/hybrid-search/SKILL.md
rubric:
  must:
    - States that sparse/payload/dense indexes and the IDF modifier are computed per shard, not per tenant
    - Concludes that in a shared collection term statistics are not tenant-isolated by default (the customer's concern is valid)
    - Explains hybrid search runs via the Query API with prefetches (each prefetch one search, combined in the outer query)
  bonus:
    - Notes prefetch runs per shard (limit x #shards retrieved under the hood, then merged by score)
    - Points toward shard-level partitioning (e.g. a shard key per tenant) if true statistical isolation is required
  avoid:
    - Claims Qdrant isolates IDF / term statistics per tenant automatically
---
We run hybrid search (dense + sparse) inside one large collection shared across all customers, partitioned by a tenant_id payload field. A customer asked whether their term statistics and scoring could be "contaminated" by other tenants' data. In a setup like ours, how does Qdrant actually scope the pieces of a hybrid query?
