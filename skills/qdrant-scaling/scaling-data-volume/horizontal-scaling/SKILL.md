---
name: qdrant-horizontal-scaling
description: "Diagnoses and guides Qdrant horizontal scaling decisions. Use when someone asks 'vertical or horizontal?', 'how many nodes?', 'how many shards?', 'how to add nodes', 'resharding', 'data doesn't fit', 'need more capacity', 'change replication factor', 'reduce replicas', or 'remove extra replicas'. Also use when data growth outpaces current deployment."
---

# What to Do When Qdrant Needs More Capacity

Vertical first: simpler operations, no network overhead, good up to ~100M vectors per node depending on dimensions and quantization. Horizontal when: data exceeds single node capacity, need fault tolerance, need to isolate tenants, or IOPS-bound (more nodes = more independent IOPS).

## Most basic distributed configuration

- 3 nodes with `replication_factor: 2` for zero-downtime scaling, and at least 2 shards per node (6 shards) so you can add nodes later without resharding [Sharding](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=sharding)

Minimum of 3 nodes is important for consensus and fault tolerance. With 3 nodes, you can lose 1 node without downtime. With 2 nodes, losing 1 node causes downtime for collection operations.
Replication factor of 2 means each shard has 1 replica, so you have 2 copies of data. This allows for zero-downtime scaling and maintenance. With `replication_factor: 1`, zero-downtime is not guaranteed even for point-level operations, and cluster maintenance requires downtime.

## Changing replication factor

Use when: raising or lowering `replication_factor` on an existing collection, or removing extra replicas.

- On Qdrant Cloud, update `replication_factor` in the collection config and stop. The Cloud platform automatically adds or drops replicas to match, and lowering it from 3 to 2 converges to 2 replicas per shard within about a minute. Do not also drop or create replicas yourself with the cluster API (`drop_replica`, `replicate_shard`, `move_shard`): your calls race with the operation of the Cloud platform and can remove more replicas than intended [Replication](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=replication)
- Verify with read-only calls: `GET /collections/{name}` for the configured factor and `GET /collections/{name}/cluster` for the replicas per shard. If the count hasn't converged yet, wait and re-check rather than intervening.
- On self-hosted, changing `replication_factor` on an existing collection does not add or remove replicas, it only sets the target. Adding or dropping replicas is a manual step with the shard APIs [Replication](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=replication)
- On self-hosted, make shard changes one at a time and re-check `GET /collections/{name}/cluster` between them. Never drop a replica if it would leave a shard with no healthy copy.

## Choosing number of shards

Shards are the unit of data distribution. 
More shards allows more nodes and better distribution, but adds overhead. Fewer shards reduces overhead but limits horizontal scaling.

For cluster of 3-6 nodes the recommended shard count is 6-12. 
This allows for 2-4 shards per node, which balances distribution and overhead. 

## Changing number of shards

Use when: shard count isn't evenly divisible by node count, causing uneven distribution, or need to rebalance.

Resharding is expensive and time-consuming, so use it as a last resort if regular data distribution is not possible. The collection stays available during resharding, with slightly reduced performance, but a lot of data moves between nodes [Resharding](https://skills.qdrant.tech/md/documentation/cloud/cluster-scaling/?s=resharding).

- Available in Qdrant Cloud [Resharding](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/?s=resharding)
- Resharding is not available for self-hosted deployments.

Better alternatives: over-provision shards initially, or spin up new cluster with correct config and migrate data.


## What NOT to Do

- Do not jump to horizontal before exhausting vertical (adds complexity for no gain)
- Do not set `shard_number` that isn't a multiple of node count (uneven distribution)
- Do not use `replication_factor: 1` in production if you need fault tolerance
- Do not drop or move replicas by hand on Qdrant Cloud after changing `replication_factor`; the Cloud platform does it, and manual calls race with it
- Do not add nodes to a self-hosted cluster without rebalancing shards (use the shard move API to redistribute); Qdrant Cloud rebalances shards automatically [Cluster scaling](https://skills.qdrant.tech/md/documentation/cloud/cluster-scaling/)
- Do not scale down RAM without load testing (cache eviction causes days-long latency incidents)
- Do not hit the collection limit by using one collection per tenant (use payload partitioning)
