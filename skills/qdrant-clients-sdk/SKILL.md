---
name: qdrant-clients-sdk
description: "Points to Qdrant's official client SDKs, the REST and gRPC API references, and the curated code-snippet search endpoint. Use when someone asks which Qdrant client to use for their language, how to install a Qdrant client, where the REST or gRPC API reference is, how to get a code example (such as uploading points), how to search Qdrant's snippet library, or whether to use REST or gRPC."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Qdrant Clients SDK

Qdrant ships official client SDKs, a REST and gRPC API, and a curated library of code snippets. Reach for an official client before writing raw HTTP calls, and prefer the REST API when starting out. [Qdrant clients](https://skills.qdrant.tech/md/documentation/interfaces/)

## Choosing and Installing a Client

Use when: picking the client for your language or setting up a new project.

- Python - [qdrant-client](https://github.com/qdrant/qdrant-client), install with `pip install qdrant-client[fastembed]`
- JavaScript / TypeScript - [qdrant-js](https://github.com/qdrant/qdrant-js), install with `npm install @qdrant/js-client-rest`
- Rust - [rust-client](https://github.com/qdrant/rust-client), install with `cargo add qdrant-client`
- Go - [go-client](https://github.com/qdrant/go-client), install with `go get github.com/qdrant/go-client`
- .NET - [qdrant-dotnet](https://github.com/qdrant/qdrant-dotnet), install with `dotnet add package Qdrant.Client`
- Java - [java-client](https://github.com/qdrant/java-client), available on [Maven Central](https://central.sonatype.com/artifact/io.qdrant/client)

## API Reference

Use when: no client exists for your language, or you need the exact request/response schema.

All interaction with Qdrant happens through the REST API or the gRPC API. Prefer REST if you are using Qdrant for the first time or working on a prototype; reach for gRPC when you need lower latency at high throughput.

- REST API - [OpenAPI reference](https://skills.qdrant.tech/api-reference.md), [source on GitHub](https://github.com/qdrant/qdrant/blob/master/docs/redoc/master/openapi.json)
- gRPC API - [protobuf definitions](https://github.com/qdrant/qdrant/tree/master/lib/api/src/grpc/proto)

## Code Examples

To obtain code examples for a specific client and use case, you can send a search request to the library of curated code snippets for the Qdrant client.

```bash
curl -X GET "https://skills.qdrant.tech/snippets/search?language=python&query=how+to+upload+points"
```

Available languages: `python`, `typescript`, `rust`, `java`, `go`, `csharp`


Response Example:

```markdown

## Snippet 1

*qdrant-client* (vlatest) — https://skills.qdrant.tech/md/documentation/manage-data/points/

Uploads multiple vector-embedded points to a Qdrant collection using the Python qdrant_client (PointStruct) with id, payload (e.g., color), and a 3D-like vector for similarity search. It supports parallel uploads (parallel=4) and a retry policy (max_retries=3) for robust indexing. The operation is idempotent: re-uploading with the same id overwrites existing points; if ids aren’t provided, Qdrant auto-generates UUIDs.

client.upload_points(
    collection_name="{collection_name}",
    points=[
        models.PointStruct(
            id=1,
            payload={
                "color": "red",
            },
            vector=[0.9, 0.1, 0.1],
        ),
        models.PointStruct(
            id=2,
            payload={
                "color": "green",
            },
            vector=[0.1, 0.9, 0.1],
        ),
    ],
    parallel=4,
    max_retries=3,
)
```

## What NOT to Do

- Hand-roll raw HTTP requests when an official client exists for your language.
- Reach for gRPC on a first prototype; start with REST and switch to gRPC only when you need the throughput.
- Guess client method names from memory instead of querying the snippet search endpoint.
- Assume a community client is officially supported; only the clients listed above are maintained by Qdrant.