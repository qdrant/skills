---
name: qdrant-multitenancy
description: "Guides tenant isolation architecture in Qdrant for multi-tenant or multi-user applications. Use when someone asks 'how to isolate customer data', 'how to build multi-tenant search/RAG', 'how many collections should I create', 'how to partition tenants by payload', 'a customer's data legally has to stay in a certain country or region'. Also use when they describe a symptom: one customer's data is way bigger than the rest and slowing everyone down, or one tenant is hogging resources."
---

# Qdrant Multitenancy

[Multitenancy](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/) is how you isolate data across multiple users or tenants within a single Qdrant deployment.

- The question to ask is: **how many tenants, and how unevenly sized are they?** That answer picks the isolation strategy.
- Understand the three isolation levels before choosing: payload-based, shard-based and collection-based.
- For almost everyone the right default is a single collection partitioned by payload, NOT a collection per tenant.

## Many Small Tenants (Default: Payload Partitioning)

Use when: you have many tenants of roughly similar, modest size. This is the recommended default for most users.

### How It Works

- Create a keyword payload index on the tenant field with `is_tenant=true` (v1.11+), so each tenant's points are stored together and read sequentially [Partition by payload](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=partition-by-payload).
- Filter every query with a `must` condition on the tenant field. Without it, a query searches every tenant's data.
- Text relevance (BM25 or sparse vectors with the IDF modifier) is scored with statistics computed over the whole shard, so tenants with different vocabularies distort each other's scores. On Qdrant 1.19 or newer, pass the `idf` search parameter with the tenant filter and index the tenant field; on 1.20 or newer this covers BM25 `text` queries on a full-text index too [Per-tenant scoring statistics](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=per-tenant-scoring-statistics).
- Every tenant indexes into the same collection, so indexing can become a bottleneck at scale. Build per-tenant HNSW graphs instead of a global one: set `payload_m` to a non-zero value explicitly (it defaults to `m`), then set `m=0`. Queries without a tenant filter get slower, so only make this trade if you hit the bottleneck and cross-tenant search is rare [Calibrate performance](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=calibrate-performance).


## A Few Large Tenants Plus a Long Tail (Tiered Multitenancy)

Use when: you have a realistic SaaS distribution: a few large customers and many small ones, possibly with small tenants that grow over time. Available in v1.16+. It avoids the noisy-neighbor problem, where one big tenant forces the whole cluster to scale, raising costs and degrading performance for everyone else.

Small tenants share a fallback shard and large tenants get dedicated shards, all in one collection. A tenant that outgrows the fallback shard can be promoted to a dedicated shard later with no downtime.

### How It Works

- Create the collection with custom sharding and `shard_number: 1`, add a fallback shard for the small tenants, and keep the `is_tenant` payload index from payload partitioning [Configure tiered multitenancy](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=configure-tiered-multitenancy).
- Promote a tenant to a dedicated shard once it approaches the indexing threshold, about 20,000 points. Qdrant moves its data with a shard transfer and keeps serving reads and writes [Promote tenant to dedicated shard](https://skills.qdrant.tech/md/documentation/manage-data/multitenancy/?s=promote-tenant-to-dedicated-shard).
- Keep in mind that re-sharding can be an expensive and time-consuming process, so consider your tenant growth patterns carefully when deciding which tenants should receive dedicated shards.
- It's not recommended to exceed ~1000 dedicated shards per cluster (resource overhead).
- The fallback shard (small tenants) must fit on a single node.
- Sharding method is fixed at collection creation: an auto-sharded collection (default) cannot be converted to custom sharding in place. If there is any realistic chance you will need to isolate a large tenant later, create the collection with custom sharding up front and put every tenant in the fallback shard.  


## Few Non-Homogenous Tenants (Collection per Tenant)

Use when: you have a limited number of tenants with different per-tenant embedding models or collection schemas.

- You should only create multiple collections when you have a limited number of tenants that need strict isolation, or when tenants' vectors are created by different embedding models. 


## Data Residency and Geographic Isolation (Custom Sharding)

Use when: data must be physically pinned to a location, e.g. regional compliance for healthcare industry (one region's data in Canada, another's in Germany). This is not only a tenant concern, a single tenant may also need to separate its own data by region.

- Like tiered multitenancy, this uses custom sharding; the difference is what you shard by. Here the shard key is a region. Each key's data lands on specific shards you can place in specific locations, while everything stays in one collection. Combine it with payload partitioning if you also need per-tenant isolation within a region. Check [User-defined sharding](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=user-defined-sharding) for setup.
- Geographic residency follows only if your cluster's nodes are actually in the target regions. 
- Qdrant Cloud deploys a cluster in a single region and has no managed multi-region today.


## What NOT to Do
- Treat a payload filter as your whole security model. In Qdrant, (unless you're using per-tenant collections), tenant isolation is payload-based. It is an application-layer responsibility, and the filter is only one small part of it.
