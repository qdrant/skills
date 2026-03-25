---
name: qdrant-tenant-scaling
description: "Guides Qdrant multi-tenant scaling. Use when someone asks 'how to scale tenants', 'one collection per tenant?', 'tenant isolation', 'dedicated shards', or reports tenant performance issues. Also use when multi-tenant workloads outgrow shared infrastructure."
---

# What to Do When Scaling Multi-Tenant Qdrant

Do not create one collection per tenant. Does not scale past a few hundred and wastes resources. One company hit the 1000 collection limit after a year of collection-per-repo and had to migrate to payload partitioning. Use a shared collection with a tenant key.

- Understand multitenancy patterns [Multitenancy](https://qdrant.tech/documentation/guides/multitenancy/)


## Tenants Are Small (< 20k points)

Use when: many tenants with small datasets sharing one deployment.

- Use a tenant ID field with keyword index [Partition by payload](https://qdrant.tech/documentation/guides/multitenancy/#partition-by-payload)
- Set `is_tenant=true` to co-locate tenant data for sequential reads [Calibrate performance](https://qdrant.tech/documentation/guides/multitenancy/#calibrate-performance)
- Disable global HNSW (`m: 0`) and use `payload_m: 16` for per-tenant indexes, dramatically faster ingestion [Calibrate performance](https://qdrant.tech/documentation/guides/multitenancy/#calibrate-performance)
- ACORN (v1.16+) significantly improves multi-tenant filter accuracy at scale [ACORN](https://qdrant.tech/documentation/concepts/search/#acorn-search-algorithm)

Hundreds of millions of points per collection is fine. Split by `org_id % N` only if filter complexity becomes a bottleneck, not for data volume.


## Tenants Are Outgrowing Shared Shards

Use when: some tenants have 20k+ points and need dedicated resources.

- Promote tenants from fallback shard to dedicated shard via tenant promotion (v1.16+) [Tiered multitenancy](https://qdrant.tech/documentation/guides/multitenancy/#tiered-multitenancy)
- Small tenants stay on fallback shards, large tenants get promoted automatically
- Use dedicated shards via user-defined sharding for full isolation [User-defined sharding](https://qdrant.tech/documentation/guides/distributed_deployment/#user-defined-sharding)


## Need Strict Tenant Isolation

Use when: legal/compliance requirements demand per-tenant encryption or strict isolation beyond what payload filtering provides.

- Multiple collections may be necessary for per-tenant encryption keys
- Limit collection count and use payload filtering within each collection
- This is the exception, not the default. Only use when compliance requires it.


## What NOT to Do

- Do not create one collection per tenant without compliance justification (does not scale past hundreds)
- Do not skip `is_tenant=true` on the tenant index (kills sequential read performance)
- Do not build global HNSW for multi-tenant collections (wasteful, use `payload_m` instead)
- Do not store ColBERT multi-vectors in RAM alongside dense vectors at scale (degrades all queries)
