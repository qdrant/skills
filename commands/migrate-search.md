---
description: Migrate deprecated client.search() calls to query_points
argument-hint: [file-or-directory]
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]
---

# Migrate Deprecated Search Calls

This command finds and migrates deprecated `client.search()` calls to the current `query_points` API.

## Arguments

The user invoked this command with: $ARGUMENTS

## Instructions

When this command is invoked:

1. Search the codebase for deprecated search methods:
   - `client.search(` (Python)
   - `client.search_points(` (Python/Rust)
   - `client.search_batch(` (Python)
   - `SearchRequest` (Python)
2. For each occurrence, rewrite to use `query_points` / `QueryPointsBuilder`:
   - `client.search("col", query_vector=vec)` becomes `client.query_points("col", query=vec)`
   - `search_params` stays as-is
   - `query_filter` stays as-is
   - `with_payload` stays as-is
   - `limit` stays as-is
3. Show a diff of each change before applying
4. After migration, verify no deprecated methods remain

## Migration Map (Python)

| Old | New |
|-----|-----|
| `client.search(collection, query_vector=v)` | `client.query_points(collection, query=v)` |
| `client.search_batch(collection, requests)` | `client.query_batch_points(collection, requests)` |
| `SearchRequest(vector=v, ...)` | `QueryRequest(query=v, ...)` |

## Example Usage

```
/qdrant:migrate-search
/qdrant:migrate-search src/search/
/qdrant:migrate-search app.py
```
