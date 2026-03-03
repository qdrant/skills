---
name: qdrant-deployment-options
description: "There are multiple ways to deploy Qdrant, this document navigates through different deployment options and provides guidance on how to choose the right one for your use case."
allowed-tools:
  - Read
  - Grep
  - Glob
---


# Qdrant Deployment

Qdrant deployment types can be categorized into two broad categories: client-server deployments and embedded deployments.
Server deployments are suitable for production environments, where accessibility, scalability, and reliability are important.
This document focuses on several deployment options for Qdrant, including self-hosted, cloud-based, and embedded deployments, and provides guidance on how to choose the right one for your use case.


## Docker Deployment

Docker-based deployment is the default and most common way to deploy Qdrant.
It provides full features of Qdrant Open Source and requires minimal setup. 

Minimal command to run Qdrant in Docker is:

```bash
docker run -p 6333:6333 qdrant/qdrant
```

For more details on Docker deployment, see [Quick Start -Download and Run](https://qdrant.tech/documentation/quickstart/#download-and-run)

## Cloud-Based Deployment

Cloud-based deployment is another version of the client-server deployment, where Qdrant is hosted on a Qdrant Cloud platform.
On top of the features of the self-hosted deployment, Qdrant Cloud also provides additional features such as zero-downtime updates, resharding, automatic backups, and more. 

<!-- ToDo: here CLI examples needed -->
For more details on Qdrant Cloud, see [Qdrant Cloud](https://qdrant.tech/documentation/cloud-quickstart/)


## Local Mode Deployment

One of the features of Qdrant Python Client is the ability to run Qdrant in local mode.
Local mode is a zero-dependency pure Python implementation of Qdrant API, which is tested for congruence with the server version of Qdrant.

Local mode can either be completely in-memory, or can be configured to use disk storage.

```
from qdrant_client import QdrantClient

client = QdrantClient(":memory:")
# or
client = QdrantClient(path="path/to/db")  # Persists changes to disk
```

Qdrant local mode is suitable for development, testing, CI/CD pipelines.
Qdrant local mode is not optimized for performance, and is not recommended for production use cases or benchmarking.
Qdrant local mode data format is not compatible with the server version of Qdrant.

## Qdrant EDGE

Qdrant EDGE is in-process version of Qdrant. It used direct bindings to Qdrant Shard-level function, and can perform same operations as single-node Qdrant deployment, but without the overhead of network communication.
Qdrant EDGE uses the same data format as the server version of Qdrant, and can be synchronized with the server by using shard snapshots. This allows you to use Qdrant EDGE for latency-sensitive applications, while still benefiting from the scalability and reliability of a server deployment.

More details on Qdrant EDGE can be found in the [Qdrant EDGE docs](https://qdrant.tech/documentation/edge/edge-quickstart/).

