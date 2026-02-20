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

1. Determine the project language from its dependency files (pyproject.toml, package.json, Cargo.toml, go.mod, .csproj, pom.xml). If unclear, ask the user.
2. Read the matching skill file (`skills/qdrant-{language}/SKILL.md`)
3. Check if the target collection already exists in the codebase and what vector names are configured
4. Generate a hybrid search using the language's idiom for:
   - `prefetch` with both dense and sparse queries
   - RRF fusion for result merging
   - Prefetch limits higher than the final limit (prefetch is the candidate pool)
5. If sparse vectors aren't set up yet, include the collection config with both dense and sparse vector params
6. Remind: BM25 requires IDF modifier. Without it, sparse search quality is poor

## Key Patterns

### Python

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

### TypeScript

```typescript
client.query('collection', {
    prefetch: [
        { query: denseEmbedding, using: 'dense', limit: 20 },
        { query: { values: sparseValues, indices: sparseIndices }, using: 'sparse', limit: 20 },
    ],
    query: { fusion: 'rrf' },
    limit: 10,
});
```

### Rust

```rust
client.query(
    QueryPointsBuilder::new("collection")
        .add_prefetch(PrefetchQueryBuilder::default()
            .query(Query::new_nearest(dense_vec))
            .using("dense")
            .limit(20u64))
        .add_prefetch(PrefetchQueryBuilder::default()
            .query(Query::new_nearest(sparse_vec))
            .using("sparse")
            .limit(20u64))
        .query(Query::new_fusion(Fusion::Rrf))
        .limit(10u64)
).await?;
```

### Go

```go
client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "collection",
    Prefetch: []*qdrant.PrefetchQuery{
        {Query: qdrant.NewQueryDense(denseVec), Using: qdrant.PtrOf("dense"), Limit: qdrant.PtrOf(uint64(20))},
        {Query: qdrant.NewQuerySparse(sparseIndices, sparseValues), Using: qdrant.PtrOf("sparse"), Limit: qdrant.PtrOf(uint64(20))},
    },
    Query: qdrant.NewQueryFusion(qdrant.Fusion_RRF),
})
```

### .NET/C#

```csharp
await client.QueryAsync("collection",
    query: Fusion.Rrf,
    prefetch: new List<PrefetchQuery>
    {
        new() { Query = denseVec, Using = "dense", Limit = 20 },
        new() { Query = sparseVec, Using = "sparse", Limit = 20 },
    },
    limit: 10);
```

### Java

```java
client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("collection")
    .addPrefetch(PrefetchQuery.newBuilder()
        .setQuery(nearest(denseVec)).setUsing("dense").setLimit(20).build())
    .addPrefetch(PrefetchQuery.newBuilder()
        .setQuery(nearest(sparseValues, sparseIndices)).setUsing("sparse").setLimit(20).build())
    .setQuery(fusion(Fusion.RRF))
    .setLimit(10).build()
).get();
```

## Example Usage

```
/qdrant:hybrid-search for my docs collection
/qdrant:hybrid-search product search with category filter
```
