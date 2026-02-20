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

1. Determine the project language from its dependency files (pyproject.toml, package.json, Cargo.toml, go.mod, .csproj, pom.xml). If unclear, ask the user.
2. Determine connection target:
   - **local**: `localhost:6333` (Python/TypeScript REST) or `localhost:6334` (Rust/Go/.NET/Java gRPC)
   - **cloud**: Qdrant Cloud URL with API key from environment variable
   - If not specified, ask the user
3. Generate connection code using the language's client:
   - API key read from environment variable (`QDRANT_API_KEY`), never hardcoded
   - Add `.env` entry if a `.env` file exists in the project
   - For Python: `QdrantClient(url=..., api_key=...)`
   - For TypeScript: `new QdrantClient({ url: ..., apiKey: ... })`
   - For Rust: `Qdrant::from_url(...).api_key(...).build()?`
   - For Go: `qdrant.NewClient(&qdrant.Config{Host: ..., Port: 6334, APIKey: ...})`
   - For .NET: `new QdrantClient(host, port: 6334, https: true, apiKey: ...)`
   - For Java: `new QdrantClient(QdrantGrpcClient.newBuilder(host, 6334, true).withApiKey(...).build())`
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

## TypeScript

```typescript
import { QdrantClient } from '@qdrant/js-client-rest';

// Local
const client = new QdrantClient({ url: 'http://127.0.0.1:6333' });

// Cloud
const client = new QdrantClient({
    url: 'https://xyz.cloud.qdrant.io',
    apiKey: process.env.QDRANT_API_KEY,
});
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

## Go

```go
import "github.com/qdrant/go-client/qdrant"

// Local
client, err := qdrant.NewClient(&qdrant.Config{
    Host: "localhost",
    Port: 6334,
})
defer client.Close()

// Cloud
client, err := qdrant.NewClient(&qdrant.Config{
    Host:   "xyz.cloud.qdrant.io",
    Port:   6334,
    APIKey: os.Getenv("QDRANT_API_KEY"),
    UseTLS: true,
})
```

## .NET/C#

```csharp
using Qdrant.Client;

// Local
var client = new QdrantClient("localhost");

// Cloud
var client = new QdrantClient(
    "xyz.cloud.qdrant.io",
    port: 6334,
    https: true,
    apiKey: Environment.GetEnvironmentVariable("QDRANT_API_KEY"));
```

## Java

```java
import io.qdrant.client.QdrantClient;
import io.qdrant.client.QdrantGrpcClient;

// Local
QdrantClient client = new QdrantClient(
    QdrantGrpcClient.newBuilder("localhost", 6334, false).build());

// Cloud
QdrantClient client = new QdrantClient(
    QdrantGrpcClient.newBuilder("xyz.cloud.qdrant.io", 6334, true)
        .withApiKey(System.getenv("QDRANT_API_KEY"))
        .build());
```

## Example Usage

```
/qdrant:connect local
/qdrant:connect cloud
/qdrant:connect
```
