---
name: qdrant-clients-sdk
description: "Qdrant provides client SDKs for various programming languages, allowing easy integration with Qdrant deployments."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Qdrant Clients SDK

Qdrant has the following officially supported client SDKs:

- Python — [qdrant-client](https://github.com/qdrant/qdrant-client) · Installation: `pip install qdrant-client[fastembed]`
- JavaScript / TypeScript — [qdrant-js](https://github.com/qdrant/qdrant-js) · Installation: `npm install @qdrant/js-client-rest`
- Rust — [rust-client](https://github.com/qdrant/rust-client) · Installation: `cargo add qdrant-client`
- Go — [go-client](https://github.com/qdrant/go-client) · Installation: `go get github.com/qdrant/go-client`
- .NET — [qdrant-dotnet](https://github.com/qdrant/qdrant-dotnet) · Installation: `dotnet add package Qdrant.Client`
- Java — [java-client](https://github.com/qdrant/java-client) · Available on Maven Central: https://central.sonatype.com/artifact/io.qdrant/client


## API Reference

All interaction with Qdrant takes place via the REST API. We recommend using REST API if you are using Qdrant for the first time or if you are working on a 
prototype.

* REST API - [OpenAPI Reference](https://api.qdrant.tech/api-reference) - [GitHub](https://github.com/qdrant/qdrant/blob/master/docs/redoc/master/openapi.json)
* gRPC API - [gRPC protobuf definitions](https://github.com/qdrant/qdrant/tree/master/lib/api/src/grpc/proto)

## Code examples

<!-- ToDo: make it work -->

To obtain code examples for a specific client and use-case, you can make a search request to library of curated code snippets for Qdrant client.

```bash
curl -X GET "https://snippets.qdrant.tech/search?client=python&query=how+to+upsert+vectors"
```

Response example:

```json
TODO
```

