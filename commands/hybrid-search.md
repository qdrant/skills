---
description: Scaffold a hybrid dense+sparse search query with RRF fusion
argument-hint: [search-description]
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]
---

# Scaffold Hybrid Search

This command generates a hybrid search query combining dense and sparse vectors with Reciprocal Rank Fusion.

## Arguments

The user invoked this command with: $ARGUMENTS

## Instructions

When this command is invoked:

1. Read the relevant skill file (`qdrant-python/SKILL.md` or `qdrant-rust/SKILL.md`) based on the project language
2. Check if the target collection already exists in the codebase and what vector names are configured
3. Generate a hybrid search using:
   - `prefetch` with both dense and sparse queries
   - `FusionQuery(fusion=Fusion.RRF)` for result fusion
   - Prefetch limits higher than the final limit (prefetch is the candidate pool)
4. If sparse vectors aren't set up yet, include the collection config with both dense and sparse vector params
5. Remind: BM25 requires `Modifier.IDF` - without it, sparse search quality is poor

## Key Pattern (Python)

```python
client.query_points("collection",
    prefetch=[
        Prefetch(query=dense_embedding, using="dense", limit=20),
        Prefetch(query=sparse_embedding, using="sparse", limit=20),
    ],
    query=FusionQuery(fusion=Fusion.RRF),
    limit=10,
)
```

## Example Usage

```
/qdrant:hybrid-search for my docs collection
/qdrant:hybrid-search product search with category filter
```
