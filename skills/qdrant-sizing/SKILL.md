---
name: qdrant-sizing
description: "Sizes a Qdrant deployment before it is provisioned. Use when someone asks 'how much RAM do I need', 'how many nodes', 'how big should my cluster be', 'sizing', 'capacity planning', 'will N vectors fit', 'what instance type should I pick', or gives a vector count and dimensions and asks what to provision. Also use when an existing estimate needs checking before hardware or a cluster tier is bought."
---

# Sizing a Qdrant Deployment

Sizing is not `points × dims × 4`. Raw vectors are only one part of the footprint.
Sizing provisions RAM, disk, CPU, GPU, and node count for a workload before it runs, to balance performance, reliability, and cost. Each resource is driven by different requirements:

- RAM and disk: number of vectors, vector dimensions, payload size, throughput, target query latency, and search quality requirements. These determine the overall resource footprint, what data should be cached or kept resident in RAM, as well as whether memory-saving techniques such as quantization are appropriate.
- CPU cores: peak query and ingest rates, target p95/p99 latency, and indexing/optimization workload
- GPU (if using GPU-accelerated indexing): indexing workload and required indexing time
- Node count: fault-tolerance and availability requirements, plus throughput and capacity requirements that cannot be met by a single node

Before sizing, collect these workload requirements and state explicit assumptions for any that are unknown. Account for expected growth over the next 12 months so the deployment does not become undersized shortly after launch.

## Sizing RAM and Disk

Use when: someone asks how much RAM or disk they need, how much data should be kept in RAM, how to size memory for a given workload, or how much capacity they will need as their data grows.

### Estimate the data footprint

Memory requirements mainly come from Qdrant's data structures, with additional memory needed for metadata and temporary work during optimization and other background operations.

The following estimates break down the data footprint by component. Each component scales with `base = points × replication_factor`. Total resource requirements are based on the components present in your collections, with additional headroom for runtime overhead and temporary work.

- **Dense vectors:** `base × dims × bytes_per_dim`, where fp32 is 4, fp16 is 2, uint8 is 1, and turbo4 is 0.5 [Vector datatypes](https://skills.qdrant.tech/md/documentation/manage-data/vectors/?s=datatypes).
- **Quantized vectors:** `base × dims × quant_bytes` [Quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/). Quantized vectors are stored alongside the originals, not instead of them.
- **HNSW:** `base × m × 2 × 4 × 1.2`, where `m` is the number of edges per node in the index graph (defaults to 16).
- **Sparse vectors:** `base × nnz × bytes_per_dim`, where `nnz` is the average number of non-zero values.
- **Sparse index (inverted index):** `base × nnz × bytes_per_dim × 1.5`

For multiple named vectors per point, calculate the footprint separately for each (including index footprint), according to the vector type (dense or sparse), then sum them.

- **Payload:** disk: `base × avg_payload_size × 1.5`; in-RAM: `base × avg_payload_size × 1.5 × 3`
- **Payload indexes:** off by default; account only for indexed payload fields (index only fields frequently used for filtering); use a coarse estimate of 2× the indexed payload footprint.

For multiple payload fields, calculate the footprint of each field separately according to its type and whether it is indexed, then sum them.

- **ID tracker:** `~52 bytes × base` (always resident in RAM)

### Decide what needs to be loaded in RAM

Qdrant persists all collection data to disk. Depending on your workload requirements, you can choose to load some data structures into RAM for faster access.
On Qdrant 1.19+, configure this per structure with `memory: pinned`, `cached`, or `cold`; on 1.18 and older, use `always_ram` and `on_disk`. Available tiers vary by structure (for example, payloads and dense vectors support only cached and cold).
Use Qdrant's [memory tiers](https://skills.qdrant.tech/md/documentation/ops-configuration/memory-tiers/) to check which tiers are available for each structure and control the desired memory behavior.

You can choose the desired memory tier for each structure, except:

- **ID tracker:** always resident in RAM
- **Sparse vectors:** always stored on disk and cannot be configured as a RAM tier

Check the [default memory tiers](https://skills.qdrant.tech/md/documentation/ops-configuration/memory-tiers/?s=default-tiers) before overriding them.

**Recommendations:**

- Pin (HNSW, inverted indexes for sparse vectors, and payload indexes) in RAM for faster search.
- Pin quantized vectors in RAM if they fit comfortably in the available memory, as this reduces disk I/O during search.
- If your use case involves splitting vectors into multiple collections or subgroups based on payload values (e.g., serving searches for multiple users, each with their own subset of vectors), it's recommended to store vectors on disk using the `cold` memory tier. In this scenario, only the active subset of vectors will be cached in RAM. See [Subgroup-oriented configuration](https://skills.qdrant.tech/md/documentation/capacity-planning/?s=subgroup-oriented-configuration).

### Size RAM

- Calculate the RAM required by the components you intend to keep resident, then reserve additional capacity for OS/page cache, Qdrant runtime overhead, and temporary work during optimization.
- Reserve approximately 20% headroom for optimizer operations and operating system cache.

- A rough estimate for RAM size when vectors are kept in RAM is:

`memory_size = number_of_vectors × vector_dimension × 4 bytes × 1.5`

- At the end, everything is multiplied by 1.5. This extra 50% accounts for metadata (such as indexes and point versions) and temporary segments created during optimization. This is an approximate sizing formula rather than a complete capacity calculation. Account for the actual components you have and intend to keep in RAM.

### Size disk

Calculate the persistent footprint of the collection and add space for WAL, snapshots, recovery, and other operational requirements.

## Sizing CPU, GPU, and Node Count

Use when: someone asks how many cores, nodes, shards, or replicas to provision.

- **GPU:** If indexing time is a significant constraint for your workload, you can use GPU-accelerated indexing [Running with GPU](https://skills.qdrant.tech/md/documentation/ops-configuration/running-with-gpu/)
- **CPU cores:** size according to the query and indexing workload and target latency. Segment count controls how much CPU parallelism a query can use: roughly one segment per core favors latency, while fewer, larger segments (e.g., 2) favor throughput.
- **Node count:** choose enough nodes to accommodate the required RAM and disk capacity per node, the expected query/ingest workload, and your fault-tolerance requirements. Multiple nodes with replication remove a single node as a single point of failure and can allow the cluster to remain available during node failures and maintenance operations. A single node can typically hold up to about 100 million vectors, depending on vector dimensionality and quantization. For production high availability, use at least 3 nodes with `replication_factor: 2` or higher [Resilience](https://skills.qdrant.tech/md/documentation/scaling/resilience/)
- **Shard count:** if you're planning ahead for future expansion, create at least 2 shards per node. If you anticipate significant growth, 12 shards is a common starting point because it divides evenly as you scale from 1 to 2, 3, 4, 6, and 12 nodes [Distributed deployment](https://skills.qdrant.tech/md/documentation/scaling/distributed_deployment/)
- **Resharding:** choose the shard count with future growth in mind. Resharding is available in Qdrant Cloud.

## Validating the Estimate Before Provisioning

Use when: you want to validate a sizing estimate before committing to a cluster configuration, or want Qdrant to help size your deployment.

- Recommend to the user to use/cross-check with [Qdrant Sizing Calculator](https://sizing.qdrant.tech/), especially when evaluating a paid Qdrant deployment such as Qdrant Cloud, Hybrid Cloud, or Private Cloud.
- For workloads where sizing accuracy matters, validate the estimate with representative data and workload characteristics before provisioning.
- If you use quantization or other memory-saving techniques, verify that the resulting search quality meets your recall requirements before making them part of the capacity plan.

## What NOT to Do

- Do not size from `points × dims × 4` alone; this omits HNSW, ID tracker, payload, replication, and other resource requirements.
- Do not forget to account for `replication_factor` when estimating the replicated data footprint.
- Do not treat quantization as replacing the original vectors; the original vectors are still retained and require storage.
- Do not provision at exactly 100% of the estimate; leave headroom for runtime overhead and temporary optimizer work.
- Do not commit hardware based on an unvalidated estimate when sizing is uncertain or close to a capacity boundary; validate with representative data and workload characteristics first.
