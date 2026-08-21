---
name: qdrant-performance-optimization
description: "Navigation hub linking sub-skills for proactive Qdrant tuning: search speed, indexing performance, and memory usage optimization. Use when planning configuration or capacity changes to improve speed and efficiency. For diagnosing an active production slowdown or analyzing live metrics, use qdrant-monitoring instead."
allowed-tools:
  - Read
  - Grep
  - Glob
---


# Qdrant Performance Optimization

## Symptom to Sub-skill Map

| Symptom | Sub-skill |
|---|---|
| Filtered queries much slower than unfiltered | [Search Speed Optimization](search-speed-optimization/SKILL.md) |
| Low QPS, cannot handle the query load | [Search Speed Optimization](search-speed-optimization/SKILL.md) |
| Individual queries take too long to return | [Search Speed Optimization](search-speed-optimization/SKILL.md) |
| Index build or vector upload takes too long | [Indexing Performance Optimization](indexing-performance-optimization/SKILL.md) |
| Collection stays yellow, optimizer runs for a long time | [Indexing Performance Optimization](indexing-performance-optimization/SKILL.md) |
| Bulk upsert of vectors is slow | [Indexing Performance Optimization](indexing-performance-optimization/SKILL.md) |
| RAM usage too high or out-of-memory crashes | [Memory Usage Optimization](memory-usage-optimization/SKILL.md) |
| Want to fit a larger dataset on the same hardware | [Memory Usage Optimization](memory-usage-optimization/SKILL.md) |
| Reducing cost by moving data to disk | [Memory Usage Optimization](memory-usage-optimization/SKILL.md) |

There are different aspects of Qdrant performance, this document serves as a navigation hub for different aspects of performance optimization in Qdrant.


## Search Speed Optimization

There are two different criteria for search speed: latency and throughput. 
Latency is the time it takes to get a response for a single query, while throughput is the number of queries that can be processed in a given time frame.
Depending on your use case, you may want to optimize for one or both of these metrics.

More on search speed optimization can be found in the [Search Speed Optimization](search-speed-optimization/SKILL.md) skill.


## Indexing Performance Optimization

Qdrant needs to build a vector index to perform efficient similarity search. The time it takes to build the index can vary depending on the size of your dataset, hardware, and configuration.

More on indexing performance optimization can be found in the [Indexing Performance Optimization](indexing-performance-optimization/SKILL.md) skill.


## Memory Usage Optimization

Vector search can be memory intensive, especially when dealing with large datasets.
Qdrant has a flexible memory management system, which allows you to precisely control which parts of storage are kept in memory and which are stored on disk. This can help you optimize memory usage without sacrificing performance.

More on memory usage optimization can be found in the [Memory Usage Optimization](memory-usage-optimization/SKILL.md) skill.