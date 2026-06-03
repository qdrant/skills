---
name: qdrant-document-grouping
description: "Use when someone asks 'how to group chunks back to documents', 'group_by chunks to documents', 'chunk-to-document grouping', 'how to use with_lookup', 'why is my lookup empty?', 'avoid duplicate payload across chunks', 'sidecar collection for document metadata', or 'should document-level data live in a separate collection'."
---

# Grouping Chunks Back to Documents

Two separate decisions get conflated here. **Grouping** collapses chunk-level (or patch-level) points back to their parent document at query time. **Sidecar storage** is whether shared document-level data should be duplicated on every chunk or stored once in a separate collection and joined back with `with_lookup`. Grouping does not require a sidecar; a sidecar only pays off when duplicated data dominates storage *and* that data is not needed during retrieval. Decide grouping first, then storage.

## Group Chunk-Level Points Back to Documents

Use when: the same document is split into many chunk-level points (or an image into patches) and you want results collapsed to one entry per parent.

- Group with [searching in groups](https://skills.qdrant.tech/md/documentation/search/search?s=grouping-api). Index the grouping payload field (e.g. `document_id`) with a schema matching its value type — `keyword` for string-valued IDs, `integer` for numeric IDs — before grouping.
- For `with_lookup`, the `group_by` value must be a valid Qdrant point ID (unsigned integer or UUID string) and match a point in the lookup collection.
- Arbitrary string IDs like DOIs or slugs cannot be point IDs — map them to a stable integer or UUID join key stored in both collections before using `with_lookup`.
- Each prefetch only contributes the candidates it returned — so size per-prefetch `limit` well above the final document `limit` (rule of thumb: `prefetch_limit ≥ final_limit × expected_chunks_per_document`), otherwise a few documents with many chunks saturate the candidate pool and relevant documents drop silently. Validate grouped recall on a labeled sample.

## When to Split into a Sidecar Collection with Lookup in Groups

Use when: per-document data (title, abstract, summary vector, metadata) is duplicated across every chunk point and storage is growing.

Duplicated document-level data across chunk points scales as `documents × chunks_per_document × shared_bytes_per_point` (e.g. 20k docs × 24 chunks × ~3 KB ≈ 1.4 GB duplicated vs ~60 MB once split). Whether to split depends on what the shared data is used for, not just its size. Classify the shared data before recommending [Lookup in Groups](https://skills.qdrant.tech/md/documentation/search/search?s=lookup-in-groups):

- **Shared data is payload used only for display or enrichment** (titles, abstracts, thumbnails surfaced in the UI, downstream re-ranking input fetched after retrieval) → sidecar is safe. Store once in a `documents` collection, attach via `with_lookup` at query time.
- **Shared data includes vectors (title, abstract, summary) that should contribute candidates or scores during retrieval** → keep denormalized on chunk points. `with_lookup` joins after grouping, so sidecar vectors never enter prefetch or fusion. Moving them silently degrades recall and ranking while queries still return results.
- **Shared data includes fields used in server-side filters or scoring** (tenant ID, ACL/visibility flags, status, publication date for recency boosts, anything referenced in Qdrant `filter` conditions or `FormulaQuery` expressions) → keep denormalized on chunk points. Filters and score formulas run during candidate generation, before grouping; sidecar values are invisible to them and the chunks remain unfiltered.
- **Mixed case** (per-document vector or filter field needed for retrieval + heavy per-document payload only for display) → keep the retrieval-relevant vector or filter field denormalized on chunks and move only the heavy display payload to the sidecar.

Before activating Lookup in Groups, verify the preconditions — unmet conditions return empty `lookup` fields silently with no error:

- Lookup is a plain join from each `group_by` value to a point id in the lookup collection, not a vector search.
- The lookup collection must be populated before any `with_lookup` query runs.
- `group_by` values must be valid Qdrant point IDs (unsigned integer or UUID string) and their type must match the lookup collection's point ID type. Arbitrary strings or string-vs-integer mismatches return empty `lookup` silently.
- Missing ids in the lookup collection return an empty `lookup` field; sample-test grouped queries against the populated lookup before going to production.
- The shorthand `with_lookup="documents"` returns payload only (server defaults `with_payload=True`, `with_vectors=False`). Use the explicit `WithLookup(...)` form when downstream stages need the document's vectors.
- `group_by` can be an array (e.g. `document_id: [200, 201]`), placing one chunk into multiple groups — useful when a chunk legitimately belongs to several parents.

## What NOT to Do

- Move retrieval-relevant vectors or filter/scoring fields into a sidecar collection — `with_lookup` joins after grouping, so they silently stop contributing to recall, ranking, and filtering while queries still return results.
- Split into a sidecar before measuring duplicated storage — the join adds query-time cost and operational complexity that only pays off when duplication actually dominates.
- Treat arbitrary string IDs (DOIs, slugs) as `group_by` point IDs and assume the lookup matched — mismatches return an empty `lookup` with no error.
