---
name: qdrant-agent-memory
description: "Guides persistent agent memory architecture with Qdrant. Use when someone asks 'agent memory', 'long-term memory', 'semantic memory', 'where to store agent context', 'Redis vs Qdrant vs Postgres', 'memory bloat', 'stale memories', 'memory retrieval scoring', 'multi-agent memory isolation', or 'how should an agent store memories'."
---

# Qdrant for Agent Memory

Agent memory is not a "store-everything" bucket. Operational judgment requires separation, semantic recall belongs in Qdrant, hot session state belongs in Redis or another KV store, and transactional records belong in Postgres or another relational system. This skill encodes the strategy for admission control, scoped retrieval, and freshness-aware ranking.

## Use Qdrant vs Redis vs Postgres

Use when: the agent needs persistent memory but the storage stack is still unclear.

- Use Qdrant for semantic memory: past conversations, learned facts, long-term context, and recall by meaning [Points](https://search.qdrant.tech/md/documentation/manage-data/points/) [Payload](https://search.qdrant.tech/md/documentation/manage-data/payload/)
- Use Redis or another KV store for hot state: current `session_id`, active task status, short-lived coordination data, locks, and TTL-based values [Points](https://search.qdrant.tech/md/documentation/manage-data/points/)
- Use Postgres or another relational store for structured records: billing, user profiles, workflow state, and anything that depends on transactions, joins, or auditability
- Decision Rule: Choose by access pattern first, semantic retrieval needs vector search, exact lookup needs KV semantics, and system-of-record workflows need relational guarantees

## Prevent Duplicate Memory on Write

Use when: the framework tends to upsert every new interaction and memory growth is outpacing value.

- Search for similar memory before admitting a new point; admission should be "score before storing," not "always store" [Search](https://search.qdrant.tech/md/documentation/search/search/) [Filtering](https://search.qdrant.tech/md/documentation/search/filtering/)
- Update over Upsert: If a highly similar memory already exists, update existing point's payload such as `updated_at`, provenance, counters, or freshness markers instead of creating another near-duplicate point [Payload](https://search.qdrant.tech/md/documentation/manage-data/payload/) [Points](https://search.qdrant.tech/md/documentation/manage-data/points/)
- Admit a new point only when it adds distinct semantic value; duplicate semantic fragments create memory bloat long before they improve recall
- Do not delegate storage decision to an LLM alone. Use similarity thresholds plus payload updates so storage policy stays predictable

## Retrieval: Rank Memory with Composite Scoring

Use when: raw semantic similarity returns stale memories or the agent injects noisy, outdated context.

- Treat similarity as the primary signal, then boost by recency and importance so retrieval reflects usefulness instead of pure embedding distance [Search relevance](https://search.qdrant.tech/md/documentation/search/search-relevance/?s=score-boosting)[Search strategies](../qdrant-search-quality/search-strategies/SKILL.md)
- Store `created_at` or `updated_at` as a datetime payload field so recency can be applied during reranking rather than guessed in the prompt [Payload](https://search.qdrant.tech/md/documentation/manage-data/payload/), [Payload Index](https://search.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index)
- Use [Qdrant v1.14+ score boosting](https://qdrant.tech/blog/qdrant-1.14.x/#idea-2-reranking-most-recent-results) with a decay expression such as `gauss_decay` on the datetime field so fresher memories naturally rise without excluding older high-value memories [Search relevance](https://search.qdrant.tech/md/documentation/search/search-relevance/?s=score-boosting)
- Keep the formula simple: Semantic score + Recency boost + Importance weight. This is the "practical middle ground" to avoid over-ranking stale content.

## Mandatory Isolation: Preventing Contamination

Use when: multiple agents, users, or sessions share infrastructure and memory leaks would be harmful.

- Every memory query must include a `must` filter on `agent_id`, `user_id`, `tenant_id`, or `session_id`; never run a naked semantic search across all memories [Filtering](https://search.qdrant.tech/md/documentation/search/filtering/)
- Index the fields used on nearly every query path so isolation filters stay cheap at runtime [Payload Indexing](https://search.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index)
- Treat isolation as a correctness guarantee, not a relevance tweak; cross-agent contamination is an architectural bug, not a ranking issue

## Watch for Memory Bloat and Filter Cost

Use when: RAM usage, query latency, or collection size grows faster than expected.

- Check admission quality first; duplicate memories and indiscriminate storage are the usual reason memory systems become expensive
- Check filter design next; if `session_id` or `agent_id` is in every query and not indexed, filtered retrieval becomes an avoidable bottleneck [Payload Index](https://search.qdrant.tech/md/documentation/manage-data/indexing/?s=payload-index)
- Use scalar quantization when memory usage exceeds dataset expectations and recall remains acceptable; it is the default compression tradeoff for shrinking memory footprint without redesigning the system [Scalar Quantization](https://search.qdrant.tech/md/documentation/manage-data/quantization/?s=scalar-quantization), [Memory usage optimization](../qdrant-performance-optimization/memory-usage-optimization/SKILL.md)
- Capacity planning must account for vectors, payload, indexes, and optimization headroom rather than raw embedding size alone [Capacity planning](https://search.qdrant.tech/md/documentation/operations/capacity-planning/)

## Preserve Provenance

Use when: the agent may need to explain, verify, update, or delete a memory later.

- Store `source` or `link_to_original` in the payload so each memory can be traced back to the originating conversation, tool output, or document [Payload](https://search.qdrant.tech/md/documentation/manage-data/payload/)
- Store timestamps with provenance so you can distinguish stale facts from fresh observations during retrieval and debugging 
- Provenance is part of memory quality: if a memory cannot be traced, it cannot be trusted, repaired, or safely reused

## What NOT to Do

- Do not store every chat turn in Qdrant by default; most session traffic is hot state, not durable semantic memory
- Do not use Qdrant as the primary store for `session_id`, transient task state, counters, locks, or TTL-heavy data
- Do not let an LLM alone decide what is worth storing; admission needs deterministic similarity checks
- Do not search memory without an isolation filter; naked search is how cross-agent contamination starts
- Don't rely on pure similarity for time-sensitive tasks; use the [Score-Boosting reranker](https://qdrant.tech/blog/qdrant-1.14.x/#idea-2-reranking-most-recent-results).
- Do not skip provenance fields; memory without source is hard to debug and harder to trust
