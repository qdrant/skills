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

1. Determine the project language from its dependency files (pyproject.toml, package.json, Cargo.toml, go.mod, .csproj, pom.xml). If unclear, ask the user.
2. Search the codebase for deprecated search methods based on the language:
   - **Python**: `client.search(`, `client.search_points(`, `client.search_batch(`, `SearchRequest`
   - **TypeScript**: `client.search(` (still works but `client.query(` is preferred)
   - **Rust**: `client.search_points(`, `SearchPointsBuilder`
   - **Go**: No legacy methods (Go client launched with the unified query API)
   - **.NET**: `client.SearchAsync(` (still works but `client.QueryAsync(` is preferred)
   - **Java**: `client.searchAsync(`, `SearchPoints.newBuilder`, `addAllVector(`
3. For each occurrence, rewrite to the modern query API
4. Show a diff of each change before applying
5. After migration, verify no deprecated methods remain

## Migration Map (Python)

| Old | New |
|-----|-----|
| `client.search(collection, query_vector=v)` | `client.query_points(collection, query=v)` |
| `client.search_batch(collection, requests)` | `client.query_batch_points(collection, requests)` |
| `SearchRequest(vector=v, ...)` | `QueryRequest(query=v, ...)` |

## Migration Map (TypeScript)

| Old | New |
|-----|-----|
| `client.search('col', { vector: v })` | `client.query('col', { query: v })` |

## Migration Map (Rust)

| Old | New |
|-----|-----|
| `SearchPointsBuilder::new("col")` | `QueryPointsBuilder::new("col")` |
| `client.search_points(req)` | `client.query(req)` |

## Migration Map (.NET)

| Old | New |
|-----|-----|
| `client.SearchAsync("col", vec)` | `client.QueryAsync("col", query: vec)` |

## Migration Map (Java)

| Old | New |
|-----|-----|
| `client.searchAsync(SearchPoints.newBuilder()...)` | `client.queryAsync(QueryPoints.newBuilder()...)` |
| `addAllVector(List.of(...))` | `setQuery(nearest(...))` |

## Example Usage

```
/qdrant:migrate-search
/qdrant:migrate-search src/search/
/qdrant:migrate-search app.py
```
