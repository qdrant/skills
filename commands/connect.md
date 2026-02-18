---
description: Set up Qdrant client connection for local or cloud
argument-hint: [local|cloud]
allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]
---

# Connect to Qdrant

This command scaffolds a Qdrant client connection with proper configuration.

## Arguments

The user invoked this command with: $ARGUMENTS

## Instructions

When this command is invoked:

1. Detect the project language (Python or Rust)
2. Determine connection target:
   - **local**: `localhost:6333` (Python REST) or `localhost:6334` (Rust gRPC)
   - **cloud**: Qdrant Cloud URL with API key from environment variable
   - If not specified, ask the user
3. Generate connection code:
   - API key read from environment variable (`QDRANT_API_KEY`), never hardcoded
   - Add `.env` entry if a `.env` file exists in the project
   - For Python: use `QdrantClient`
   - For Rust: use `Qdrant::from_url().api_key().build()`
4. Verify the connection works by listing collections

## Python

```python
from qdrant_client import QdrantClient
import os

# Local
client = QdrantClient("localhost", port=6333)

# Cloud
client = QdrantClient(
    url="https://xyz.cloud.qdrant.io:6333",
    api_key=os.environ["QDRANT_API_KEY"],
)
```

## Rust

```rust
use qdrant_client::Qdrant;

// Local
let client = Qdrant::from_url("http://localhost:6334").build()?;

// Cloud
let client = Qdrant::from_url("https://xyz.cloud.qdrant.io:6334")
    .api_key(std::env::var("QDRANT_API_KEY"))
    .build()?;
```

## Example Usage

```
/qdrant:connect local
/qdrant:connect cloud
/qdrant:connect
```
