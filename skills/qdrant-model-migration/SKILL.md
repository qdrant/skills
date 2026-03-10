---
name: qdrant-model-migration
description: "Guides embedding model migration in Qdrant without downtime. Use when someone asks 'how to switch embedding models', 'how to migrate vectors', 'how to update to a new model', 'zero-downtime model change', 'how to re-embed my data', or 'can I use two models at once'. Also use when upgrading model dimensions, switching providers, or A/B testing models."
---

# What to Do When Changing Embedding Models

Vectors from different models are incompatible. You cannot mix old and new embeddings in the same vector space. The migration strategy depends on whether you can afford re-embedding time and whether you need zero downtime.


## Strategy 1: Collection Alias Swap (Zero Downtime)

Use when: production must stay available during migration. This is the recommended approach.

1. Create a new collection with the new model's dimensions and config
2. Re-embed all data into the new collection in the background
3. Point your application at a collection alias instead of a direct collection name
4. Atomically swap the alias to the new collection [Collection aliases](https://qdrant.tech/documentation/concepts/collections/#collection-aliases)
5. Verify results, then delete the old collection

The alias swap is atomic. No requests are affected during the switch. [Switch collection](https://qdrant.tech/documentation/concepts/collections/#switch-collection)


## Strategy 2: Named Vectors (Side-by-Side)

Use when: you want to keep both old and new embeddings on the same points, or A/B test models.

- Add a new named vector field to the existing collection with the new model's dimensions [Named vectors](https://qdrant.tech/documentation/concepts/vectors/#named-vectors)
- Each named vector can have its own distance metric, HNSW config, and quantization config [Collection with multiple vectors](https://qdrant.tech/documentation/concepts/collections/#collection-with-multiple-vectors)
- Re-embed data into the new vector field while old field remains searchable
- Switch queries to use the new vector name once migration is complete
- Optionally delete the old vector field to reclaim storage

Trade-off: doubles storage during migration since both vector sets coexist.


## Strategy 3: Recreate In-Place (With Downtime)

Use when: downtime is acceptable, dataset is small, or this is a dev/staging environment.

- Delete the collection and recreate with new dimensions
- Re-embed and re-upload all data
- Simplest approach but causes full service interruption


## Handling Dimension Changes

Use when: new model has different vector dimensions than the old one.

- Collection alias swap handles this naturally (new collection has new dimensions)
- Named vectors also support different dimensions per vector field
- If using Matryoshka models, you can test at smaller dimensions before committing to full size [Matryoshka / MRL](https://qdrant.tech/documentation/concepts/inference/#reduce-vector-dimensionality-with-matryoshka-models)
- Consider float16 or uint8 datatypes for the new vectors to reduce memory [Datatypes](https://qdrant.tech/documentation/concepts/vectors/#datatypes)


## Re-embedding at Scale

Use when: dataset is large and re-embedding is the bottleneck.

- Use batch embedding APIs from your model provider to maximize throughput
- Upload in parallel batches (64-256 points per request, 2-4 parallel streams) [Bulk upload](https://qdrant.tech/documentation/tutorials-develop/bulk-upload/)
- Disable HNSW during bulk load (set `indexing_threshold_kb` very high, restore after) [Collection params](https://qdrant.tech/documentation/concepts/collections/#update-collection-parameters)
- For Qdrant Cloud inference models, embedding is handled server-side [Inference docs](https://qdrant.tech/documentation/concepts/inference/)


## What NOT to Do

- Mix vectors from different models in the same vector field (results will be meaningless)
- Delete the old collection before verifying the new one works correctly
- Forget to update the query embedding model in your application code (must match the collection's model)
- Skip payload migration when using the alias swap strategy (payloads must be re-uploaded to the new collection)
- Use in-place recreation for production workloads when alias swap is available
