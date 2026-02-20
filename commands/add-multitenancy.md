---
description: Add tenant isolation to an existing Qdrant collection
argument-hint: [tenant-field-name]
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]
---

# Add Multi-Tenancy

This command adds tenant isolation to an existing Qdrant collection using payload indexes and per-query filtering.

## Arguments

The user invoked this command with: $ARGUMENTS

## Instructions

When this command is invoked:

1. Determine the project language from its dependency files (pyproject.toml, package.json, Cargo.toml, go.mod, .csproj, pom.xml). If unclear, ask the user.
2. Read the matching skill file (`skills/qdrant-{language}/SKILL.md`)
3. Find the existing collection setup in the codebase
4. Determine the tenant field name (default: `tenant_id`, or use what the user provides)
5. Generate:
   - A payload index with tenant flag on the tenant field
   - A filter wrapper that adds the tenant condition to every query
   - Updated upsert code that includes the tenant field in every point's payload
6. Warn: NEVER create one collection per user/tenant. Always use a single collection with tenant filtering.

## Key Patterns

### Python

```python
client.create_payload_index("collection", "tenant_id",
    field_schema=PayloadSchemaType.KEYWORD, is_tenant=True)

client.query_points("collection", query=embedding,
    query_filter=Filter(must=[
        FieldCondition(key="tenant_id", match=MatchValue(value=current_tenant)),
    ]), limit=10)
```

### TypeScript

```typescript
client.createPayloadIndex('collection', {
    field_name: 'tenant_id',
    field_schema: { type: 'keyword', is_tenant: true },
});

client.query('collection', {
    query: embedding,
    filter: { must: [{ key: 'tenant_id', match: { value: currentTenant } }] },
    limit: 10,
});
```

### Rust

```rust
client.create_field_index(
    CreateFieldIndexCollectionBuilder::new("collection", "tenant_id", FieldType::Keyword)
        .is_tenant(true)
).await?;

client.query(QueryPointsBuilder::new("collection")
    .query(vec![...])
    .filter(Filter::must([Condition::matches("tenant_id", current_tenant.to_string())]))
    .limit(10u64)
).await?;
```

### Go

```go
client.CreateFieldIndex(ctx, &qdrant.CreateFieldIndexCollection{
    CollectionName: "collection", FieldName: "tenant_id",
    FieldType: qdrant.FieldType_FieldTypeKeyword.Enum(),
    IsTenant: qdrant.PtrOf(true),
})

client.Query(ctx, &qdrant.QueryPoints{
    CollectionName: "collection", Query: qdrant.NewQuery(embedding...),
    Filter: &qdrant.Filter{Must: []*qdrant.Condition{qdrant.NewMatch("tenant_id", currentTenant)}},
    Limit: qdrant.PtrOf(uint64(10)),
})
```

### .NET/C#

```csharp
await client.CreatePayloadIndexAsync("collection", "tenant_id",
    PayloadSchemaType.Keyword, isTenant: true);

await client.QueryAsync("collection", query: embedding,
    filter: MatchKeyword("tenant_id", currentTenant), limit: 10);
```

### Java

```java
client.createPayloadIndexAsync("collection", "tenant_id",
    PayloadSchemaType.Keyword, null, null, null, true).get();

client.queryAsync(QueryPoints.newBuilder()
    .setCollectionName("collection")
    .setQuery(nearest(embedding))
    .setFilter(Filter.newBuilder()
        .addMust(matchKeyword("tenant_id", currentTenant)).build())
    .setLimit(10).build()
).get();
```

## Example Usage

```
/qdrant:add-multitenancy user_id
/qdrant:add-multitenancy org_id for my documents collection
```
