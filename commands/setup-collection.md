---
description: Create a Qdrant collection with proper vector config, distance metric, and payload indexes
argument-hint: [collection-description]
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]
---

# Set Up Qdrant Collection

This command walks through creating a properly configured Qdrant collection.

## Arguments

The user invoked this command with: $ARGUMENTS

## Instructions

When this command is invoked:

1. Determine the project language from its dependency files (pyproject.toml, package.json, Cargo.toml, go.mod, .csproj, pom.xml). If unclear, ask the user.
2. Read the matching skill file (`skills/qdrant-{language}/SKILL.md`)
3. Ask the user:
   - Collection name
   - What they're storing (to determine vector dimensions and distance metric)
   - Whether they need multi-tenancy
   - Whether they need hybrid search (dense + sparse)
4. Generate the collection creation code with:
   - Vector config with correct size and distance (using the language's idiom)
   - Sparse vector config if hybrid search is needed
   - Payload indexes created BEFORE any data upload
   - Tenant payload index if multi-tenant
5. Remind the user: create payload indexes before bulk upload, not after

## Common Configurations

| Use case | Distance | Notes |
|----------|----------|-------|
| Semantic similarity | Cosine | Most embedding models use cosine |
| Image search | Cosine or Euclid | Depends on model |
| Exact matching | Dot | When vectors are normalized |

## Example Usage

```
/qdrant:setup-collection product catalog with filtering by category and price
/qdrant:setup-collection multi-tenant RAG with hybrid search
/qdrant:setup-collection image embeddings from CLIP
```
