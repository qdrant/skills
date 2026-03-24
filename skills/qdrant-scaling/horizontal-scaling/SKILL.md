---
name: qdrant-horizontal-scaling
description: "Diagnoses and guides Qdrant horizontal scaling decisions. Use when someone asks 'vertical or horizontal?', 'how many nodes?', 'how many shards?', 'how to add nodes', 'resharding', 'data doesn't fit', or 'need more capacity'. Also use when data growth outpaces current deployment."
---

# What to Do When Qdrant Needs More Capacity

There are typical two types of scaling: vertical (bigger nodes) and horizontal (more nodes). Each has trade-offs. Vertical is simpler but limited by single node capacity. Horizontal is more complex but can scale indefinitely with enough nodes. When should you choose one over the other?

Vertical first: simpler operations, no network overhead, good up to ~100M vectors per node depending on dimensions and quantization. Horizontal when: data exceeds single node capacity, need fault tolerance, need to isolate tenants, or IOPS-bound (more nodes = more independent IOPS).

- Estimate memory needs: `num_vectors * dimensions * 4 bytes * 1.5` plus payload and index overhead. Reserve 20% headroom for optimizations. **Use the Bash tool to calculate this with the user's actual values — do not compute mentally.** [Capacity planning](https://qdrant.tech/documentation/guides/capacity-planning/)
  ```bash
  python3 -c "
  num_vectors = 1_000_000  # replace with actual value
  dimensions = 1536        # replace with actual value
  print(f'{num_vectors * dimensions * 4 * 1.5 * 1.2 / 1e9:.2f} GB required')
  "
  ```


## Not Ready to Scale Yet

Use when: planning to scale but haven't started. Cover these prerequisites before proceeding.

- Minimum 3 nodes with `replication_factor: 2` for zero-downtime scaling
- Set up monitoring (Grafana/Prometheus) BEFORE scaling

See [Prerequisites](https://qdrant.tech/documentation/guides/distributed_deployment/#enabling-distributed-mode-in-self-hosted-qdrant)


## Data Doesn't Fit on One Node

Use when: approaching memory or disk limits on a single node.

- Use quantization to reduce vector memory by 4x (scalar) or 32x (binary) [Quantization](https://qdrant.tech/documentation/guides/quantization/)
- Use mmap storage to keep vectors on disk with RAM as cache [Choosing disk over RAM](https://qdrant.tech/documentation/guides/capacity-planning/#choosing-disk-over-ram)
- If still not enough, add nodes with sharding [Sharding](https://qdrant.tech/documentation/guides/distributed_deployment/#sharding)

Most people jump to horizontal too early. Exhaust vertical options first.


## Need to Change Shard Count

Use when: shard count isn't evenly divisible by node count, causing uneven distribution, or need to rebalance.

Resharding is expensive and time-consuming. Hours to weeks depending on data size. Locks segments during transfer, queries may timeout under high concurrency.

- Available in Qdrant Cloud (v1.13+) [Resharding](https://qdrant.tech/documentation/guides/distributed_deployment/#resharding)
- For self-hosted, requires recreating the collection with the new shard count
- Move shards between nodes to rebalance load [Moving shards](https://qdrant.tech/documentation/guides/distributed_deployment/#moving-shards)
- List existing shard keys via API (v1.17+) [User-defined sharding](https://qdrant.tech/documentation/guides/distributed_deployment/#user-defined-sharding)

Better alternatives: over-provision shards initially, or spin up new cluster with correct config and migrate data.


## Planning for Future Growth

Use when: setting up a new cluster and want to avoid resharding later.

- Estimate data growth to 2-3 year projection
- Choose LCM shard count: 48 shards works for 12, 16, or 24 nodes. 24 shards works for 6, 8, 12, or 24 nodes.
- `shard_number` should be 1-2x current node count (allows 2x growth)


## What NOT to Do

- Do not jump to horizontal before exhausting vertical (adds complexity for no gain)
- Do not set `shard_number` that isn't a multiple of node count (uneven distribution)
- Do not use `replication_factor: 1` in production if you need fault tolerance
- Do not add nodes without rebalancing shards (use shard move API to redistribute)
- Do not scale down RAM without load testing (cache eviction causes days-long latency incidents)
- Do not hit the collection limit by using one collection per tenant (use payload partitioning)
