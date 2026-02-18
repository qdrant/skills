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

1. Read the relevant skill file (`qdrant-python/SKILL.md` or `qdrant-rust/SKILL.md`) based on the project language
2. Find the existing collection setup in the codebase
3. Determine the tenant field name (default: `tenant_id`, or use what the user provides)
4. Generate:
   - A payload index with `is_tenant=True` on the tenant field
   - A filter wrapper that adds the tenant condition to every query
   - Updated upsert code that includes the tenant field in every point's payload
5. Warn: NEVER create one collection per user/tenant. Always use a single collection with tenant filtering.

## Key Pattern (Python)

```python
# Create tenant index (do this once, before bulk upload)
client.create_payload_index(
    "collection",
    "tenant_id",
    field_schema=PayloadSchemaType.KEYWORD,
    is_tenant=True,
)

# Every query must include the tenant filter
client.query_points("collection",
    query=embedding,
    query_filter=Filter(must=[
        FieldCondition(key="tenant_id", match=MatchValue(value=current_tenant)),
    ]),
    limit=10,
)
```

## Example Usage

```
/qdrant:add-multitenancy user_id
/qdrant:add-multitenancy org_id for my documents collection
```
