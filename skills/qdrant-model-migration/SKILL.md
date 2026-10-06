---
name: qdrant-model-migration
description: "Guides embedding model migration in Qdrant without downtime. Use when someone asks 'how to switch embedding models', 'how to migrate vectors', 'how to update to a new model', 'zero-downtime model change', 'how to re-embed my data', or 'can I use two models at once'. Also use when upgrading model dimensions, switching providers, or A/B testing models."
---

# What to Do When Changing Embedding Models

Vectors from different models are incompatible. You cannot mix old and new embeddings in the same vector space. On v1.18+, you can add or delete named vector fields on an existing collection — migration no longer always requires a new collection. On v1.17 or earlier, all named vectors must be defined at collection creation time.

- Understand collection aliases before choosing a strategy [Collection aliases](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=collection-aliases)


## Can I Avoid Re-embedding?

Use when: looking for shortcuts before committing to full migration.

You MUST re-embed if: changing model provider (OpenAI to Cohere), changing architecture (CLIP to BGE), or switching to a model with a different dimension count.

You do NOT need to re-embed existing dense vectors if:

- Adding sparse vectors for hybrid search: generate only the sparse vectors. On v1.18+, add the sparse field to the existing collection and backfill it with `UpdateVectors`. On v1.17 or earlier, copy the dense vectors into the new collection instead of recomputing them [Update vectors](https://skills.qdrant.tech/md/documentation/manage-data/points/?s=update-vectors)
- Using Matryoshka models: use the `dimensions` parameter to output lower-dimensional embeddings (some recall loss, good for 100M+ datasets)
- Changing quantization (binary to scalar): Qdrant re-quantizes automatically [Quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/)


## Need Zero Downtime

Use when: production must stay available. Recommended for model replacement at scale.

- Enable dual writes before backfill, preserving point IDs. Retry and reconcile failed writes to either destination [Migration workflow](https://skills.qdrant.tech/md/documentation/tutorials-operations/embedding-model-migration/)

- If the cluster is v1.18 or later AND the collection has named vectors:

  - Add the new vector field directly to the existing collection [Update vector schema](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=update-vector-schema)
  - Write both embeddings on incoming upserts; backfill only the new field with `UpdateVectors`. Pause updates/deletes to existing points and drain in-flight operations first, or implement conflict handling to prevent stale backfill [Named-vector migration](https://skills.qdrant.tech/md/documentation/tutorials-operations/embedding-model-migration/?s=migrate-using-named-vectors)
  - After validating completeness and quality, switch the query embedding model and `using` together; an alias cannot select a vector field

- If the cluster is v1.17 or earlier OR the collection doesn't have named vectors:

  - Create a new collection with the new model's dimensions and distance metric
  - Dual-write live upserts to both collections; backfill embeddings and payloads with `update_mode: insert_only` (v1.17+) to preserve points already written live. Pause deletes/partial updates or reconcile them so backfill cannot resurrect deleted data [Blue-green migration](https://skills.qdrant.tech/md/documentation/tutorials-operations/embedding-model-migration/?s=blue-green-migration)
  - Point your application at a collection alias instead of a direct collection name
  - Validate completeness and quality before swapping the alias; coordinate the query-model change so requests use the matching vector space [Switch collection](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=switch-collection)

Keep dual writes through an observation period for rollback. Retire old vectors or collections only after all readers switch and rollback is no longer needed. Aliases redirect requests; they do not copy payloads.


## Need Both Models Live (Side-by-Side)

Use when: A/B testing models, multi-modal (dense + sparse), or evaluating a new model before committing.

For a live collection, apply the write-consistency and cutover safeguards in **Need Zero Downtime**.

- If the cluster is v1.18 or later:

  - Add the new vector field directly to the existing collection [Update vector schema](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=update-vector-schema)
  - Backfill new model embeddings incrementally using `UpdateVectors` [Update vectors](https://skills.qdrant.tech/md/documentation/manage-data/points/?s=update-vectors)

- If the cluster is v1.17 or earlier: You cannot add a named vector to an existing collection. Create a new collection with both vector fields defined upfront:

  - Create new collection with old and new named vectors both defined [Collection with multiple vectors](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=collection-with-multiple-vectors)
  - Migrate data from old collection, preserving existing vectors in the old named field
  - Backfill new model embeddings incrementally using `UpdateVectors` [Update vectors](https://skills.qdrant.tech/md/documentation/manage-data/points/?s=update-vectors)
  - Compare quality by querying with `using: "old_model"` vs `using: "new_model"`
  - Swap alias to new collection once satisfied

Co-locating large multi-vectors (especially ColBERT) with dense vectors degrades ALL queries, even those only using dense. At millions of points, users report 13s latency dropping to 2s after removing ColBERT. Put large vectors on disk during side-by-side migration.

If you anticipate future model migrations, define both vector fields upfront at collection creation.


## Dense to Hybrid Search Migration

Use when: adding sparse/BM25 vectors to an existing dense-only collection. Most common migration pattern.

- If the cluster is v1.18 or later, add the sparse vector field directly, even if the dense vector is unnamed [Update vector schema](https://skills.qdrant.tech/md/documentation/manage-data/collections/?s=update-vector-schema)
  - Generate sparse vectors for existing points and backfill with `UpdateVectors`; existing dense vectors stay as they are [Update vectors](https://skills.qdrant.tech/md/documentation/manage-data/points/?s=update-vectors)

- If the cluster is v1.17 or earlier, you cannot add sparse vectors to an existing collection. Recreate it:

  - Create new collection with both dense and sparse vector configs defined
  - Scroll the old collection with `with_vectors=True` to copy the dense vectors, and generate only the sparse vectors
  - Migrate payloads, swap alias

Sparse vectors at chunk level have different TF-IDF characteristics than document level. Test retrieval quality after migration, especially for non-English text without stop-word removal.


## Re-embedding Is Too Slow

Use when: dataset is large and re-embedding is the bottleneck.

- Use `update_mode: insert_only` (v1.17+) for backfill into a new collection; it skips existing destination points, so it is not a replacement for `UpdateVectors` when adding embeddings to existing points [Update mode](https://skills.qdrant.tech/md/documentation/manage-data/points/?s=update-mode)
- Scroll the old collection with `with_vectors=False`, re-embed in batches, upsert into new collection
- Upload in parallel batches (64-256 points per request, 2-4 parallel streams) [Bulk upload](https://skills.qdrant.tech/md/documentation/manage-data/bulk-upload/)
- For a new destination collection not yet serving queries, consider raising `optimizers_config.indexing_threshold` to delay HNSW construction during bulk load. Restore the original value and let indexing finish before cutover; avoid applying this blindly to an in-place migration serving searches [Optimizer configuration](https://skills.qdrant.tech/md/documentation/ops-optimization/optimizer/?s=per-collection-optimizer-configuration)
- For Qdrant Cloud inference, switching models is a config change, not a pipeline change [Inference docs](https://skills.qdrant.tech/md/documentation/inference/)

For 400GB+ datasets, expect days. For small datasets (<25MB), re-indexing from source is faster than using the migration tool.


## What NOT to Do

- Assume you can add named vectors to an existing collection on v1.17 or earlier servers; check your server version first
- Delete old vectors or collections before validation, reader cutover, and the rollback observation period
- Assume dual writes or `insert_only` alone resolve concurrent deletes and partial updates
- Forget to update the query embedding model in your application code
- Skip payload migration when using alias swap (aliases redirect requests, they do not copy data)
- Keep ColBERT vectors co-located with dense vectors during a long migration (I/O cost degrades all queries)
- Migrate to hybrid search without testing BM25 quality at chunk level
