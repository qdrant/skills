# Weekly Skill Scorecard — 20260808

## Lift per model (with-skill − no-skill)

| model  | must_coverage no→with | must lift ± SE | 95% CI != 0? | Δbonus | Δavoid | Δcost ($) | Δturns |
| ------ | --------------------- | -------------- | ------------ | ------ | ------ | --------- | ------ |
| sonnet | 0.590 → 0.909         | +0.319 ± 0.059 | yes          | +0.478 | -0.23  | +0.0265   | +3.2   |
| haiku  | 0.393 → 0.769         | +0.376 ± 0.076 | yes          | +0.330 | -0.17  | +0.0079   | +2.6   |

_± SE is one within-week standard error of the paired per-prompt must-coverage lift — this week's sampling uncertainty (finite prompt set + run/judge noise), **not** between-week drift. '≠ 0?' asks whether the 95% CI (t·SE) excludes zero: 'no' means don't act on this lift yet. Δbonus/Δavoid appear only when the skill changed bonus depth or introduced/removed a violation. Δcost/Δturns are within-model only; negative = cheaper/sooner. Note: turns counts all conversation messages, including tool-result messages, not just the model's own turns. Reported, not gated._

## Week-over-week lift delta

**Will be computed after four runs.** (this is run 1 of 4; a delta needs prior runs to estimate the between-week noise floor. This week's own sampling uncertainty is in the lift table above as ± SE.)

## Per-cell metrics

| model  | condition  | must_cov | bonus_rate | avoid_viol | composite | mean cost | mean turns | n  |
| ------ | ---------- | -------- | ---------- | ---------- | --------- | --------- | ---------- | -- |
| sonnet | no-skill   | 0.590    | 0.192      | 0.25       | 0.548     | 0.0798    | 1.9        | 26 |
| sonnet | with-skill | 0.909    | 0.670      | 0.02       | 0.917     | 0.1063    | 5.1        | 26 |
| haiku  | no-skill   | 0.393    | 0.109      | 0.23       | 0.380     | 0.0102    | 1.0        | 26 |
| haiku  | with-skill | 0.769    | 0.439      | 0.06       | 0.771     | 0.0181    | 3.6        | 26 |

## Per-prompt (must_coverage; with-skill lift)

| prompt                                   | model  | must no→with  | must lift | comp no→with  |
| ---------------------------------------- | ------ | ------------- | --------- | ------------- |
| qdrant-clients-sdk                       | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-clients-sdk                       | haiku  | 0.000 → 1.000 | +1.000    | 0.025 → 1.000 |
| qdrant-deployment-options                | sonnet | 0.667 → 1.000 | +0.333    | 0.692 → 1.000 |
| qdrant-deployment-options                | haiku  | 0.667 → 0.667 | +0.000    | 0.717 → 0.642 |
| qdrant-edge                              | sonnet | 0.300 → 1.000 | +0.700    | 0.000 → 1.000 |
| qdrant-edge                              | haiku  | 0.100 → 1.000 | +0.900    | 0.000 → 1.000 |
| qdrant-horizontal-scaling                | sonnet | 0.875 → 1.000 | +0.125    | 0.775 → 1.000 |
| qdrant-horizontal-scaling                | haiku  | 0.875 → 1.000 | +0.125    | 0.875 → 1.000 |
| qdrant-hybrid-search                     | sonnet | 0.833 → 0.833 | +0.000    | 0.858 → 0.858 |
| qdrant-hybrid-search                     | haiku  | 0.167 → 0.500 | +0.333    | 0.167 → 0.525 |
| qdrant-hybrid-search-combining           | sonnet | 0.200 → 1.000 | +0.800    | 0.200 → 1.000 |
| qdrant-hybrid-search-combining           | haiku  | 0.200 → 0.400 | +0.200    | 0.200 → 0.450 |
| qdrant-hybrid-search-prefetches          | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-hybrid-search-prefetches          | haiku  | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-indexing-performance-optimization | sonnet | 0.625 → 0.875 | +0.250    | 0.375 → 0.925 |
| qdrant-indexing-performance-optimization | haiku  | 0.500 → 0.875 | +0.375    | 0.400 → 0.900 |
| qdrant-memory-usage-optimization         | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-memory-usage-optimization         | haiku  | 0.500 → 1.000 | +0.500    | 0.533 → 1.000 |
| qdrant-minimize-latency                  | sonnet | 0.333 → 0.833 | +0.500    | 0.083 → 0.708 |
| qdrant-minimize-latency                  | haiku  | 0.333 → 0.333 | +0.000    | 0.333 → 0.333 |
| qdrant-model-migration                   | sonnet | 0.375 → 0.875 | +0.500    | 0.375 → 0.900 |
| qdrant-model-migration                   | haiku  | 0.125 → 1.000 | +0.875    | 0.125 → 1.000 |
| qdrant-monitoring                        | sonnet | 0.333 → 0.667 | +0.333    | 0.358 → 0.692 |
| qdrant-monitoring                        | haiku  | 0.333 → 0.667 | +0.333    | 0.333 → 0.667 |
| qdrant-monitoring-debugging              | sonnet | 0.750 → 1.000 | +0.250    | 0.800 → 1.000 |
| qdrant-monitoring-debugging              | haiku  | 0.125 → 1.000 | +0.875    | 0.175 → 1.000 |
| qdrant-monitoring-setup                  | sonnet | 0.375 → 1.000 | +0.625    | 0.375 → 1.000 |
| qdrant-monitoring-setup                  | haiku  | 0.250 → 1.000 | +0.750    | 0.250 → 1.000 |
| qdrant-performance-optimization          | sonnet | 0.000 → 0.833 | +0.833    | 0.025 → 0.883 |
| qdrant-performance-optimization          | haiku  | 0.500 → 0.667 | +0.167    | 0.525 → 0.692 |
| qdrant-relevance-feedback                | sonnet | 0.500 → 0.875 | +0.375    | 0.375 → 0.900 |
| qdrant-relevance-feedback                | haiku  | 0.000 → 0.875 | +0.875    | 0.000 → 0.900 |
| qdrant-scaling-data-volume               | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-scaling-data-volume               | haiku  | 0.833 → 1.000 | +0.167    | 0.708 → 1.000 |
| qdrant-scaling-qps                       | sonnet | 0.500 → 0.500 | +0.000    | 0.500 → 0.500 |
| qdrant-scaling-qps                       | haiku  | 0.167 → 0.833 | +0.667    | 0.167 → 0.833 |
| qdrant-scaling-query-volume              | sonnet | 0.000 → 0.667 | +0.667    | 0.000 → 0.767 |
| qdrant-scaling-query-volume              | haiku  | 0.000 → 0.667 | +0.667    | 0.000 → 0.767 |
| qdrant-search-quality-diagnosis          | sonnet | 0.750 → 1.000 | +0.250    | 0.750 → 1.000 |
| qdrant-search-quality-diagnosis          | haiku  | 0.625 → 0.750 | +0.125    | 0.625 → 0.750 |
| qdrant-search-speed-optimization         | sonnet | 0.500 → 0.667 | +0.167    | 0.500 → 0.717 |
| qdrant-search-speed-optimization         | haiku  | 0.333 → 0.333 | +0.000    | 0.333 → 0.333 |
| qdrant-search-strategies                 | sonnet | 1.000 → 1.000 | +0.000    | 0.750 → 1.000 |
| qdrant-search-strategies                 | haiku  | 1.000 → 0.750 | -0.250    | 0.775 → 0.675 |
| qdrant-sliding-time-window               | sonnet | 0.833 → 1.000 | +0.167    | 0.850 → 1.000 |
| qdrant-sliding-time-window               | haiku  | 0.333 → 0.167 | -0.167    | 0.367 → 0.200 |
| qdrant-tenant-scaling                    | sonnet | 0.750 → 1.000 | +0.250    | 0.750 → 1.000 |
| qdrant-tenant-scaling                    | haiku  | 0.250 → 0.500 | +0.250    | 0.250 → 0.375 |
| qdrant-version-upgrade                   | sonnet | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-version-upgrade                   | haiku  | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-vertical-scaling                  | sonnet | 0.833 → 1.000 | +0.167    | 0.850 → 1.000 |
| qdrant-vertical-scaling                  | haiku  | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |

## Activation / trigger misses

- with-skill runs: **104**
- **trigger misses** (activation=none — skill present but never reached): **12**
- lift sourced from the published site (activation=web_fetch, not the local SKILL.md): **0**

| prompt                                   | activations (with-skill)  | reached leaf |
| ---------------------------------------- | ------------------------- | ------------ |
| qdrant-clients-sdk                       | skill_tool×4              | 0/4          |
| qdrant-deployment-options                | skill_tool×4              | 0/4          |
| qdrant-edge                              | skill_tool×4              | 0/4          |
| qdrant-horizontal-scaling                | skill_tool×4              | 4/4          |
| qdrant-hybrid-search                     | none×1, skill_tool×3      | 1/4          |
| qdrant-hybrid-search-combining           | skill_tool×4              | 3/4          |
| qdrant-hybrid-search-prefetches          | skill_tool×4              | 2/4          |
| qdrant-indexing-performance-optimization | skill_tool×4              | 4/4          |
| qdrant-memory-usage-optimization         | skill_tool×4              | 4/4          |
| qdrant-minimize-latency                  | none×3, skill_tool×1      | 1/4          |
| qdrant-model-migration                   | skill_tool×4              | 0/4          |
| qdrant-monitoring                        | none×4  ⚠ never triggered | 0/4          |
| qdrant-monitoring-debugging              | skill_tool×4              | 4/4          |
| qdrant-monitoring-setup                  | skill_tool×4              | 4/4          |
| qdrant-performance-optimization          | skill_tool×4              | 0/4          |
| qdrant-relevance-feedback                | skill_tool×4              | 2/4          |
| qdrant-scaling-data-volume               | skill_tool×4              | 4/4          |
| qdrant-scaling-qps                       | none×2, skill_tool×2      | 2/4          |
| qdrant-scaling-query-volume              | skill_tool×4              | 4/4          |
| qdrant-search-quality-diagnosis          | skill_tool×4              | 3/4          |
| qdrant-search-speed-optimization         | skill_tool×4              | 2/4          |
| qdrant-search-strategies                 | skill_tool×4              | 3/4          |
| qdrant-sliding-time-window               | none×2, skill_tool×2      | 2/4          |
| qdrant-tenant-scaling                    | skill_tool×4              | 2/4          |
| qdrant-version-upgrade                   | skill_tool×4              | 0/4          |
| qdrant-vertical-scaling                  | skill_tool×4              | 2/4          |

## Lift caveat — baseline self-served the skill

- no-skill runs that fetched `skills.qdrant.tech`: **0 of 104**

## `avoid` violations (most damaging failures)

| prompt                                   | model  | condition  | violated item                                                                    | evidence                                                                                  |
| ---------------------------------------- | ------ | ---------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| qdrant-deployment-options                | haiku  | with-skill | Recommends self-managed distributed Docker as the production target despite the  | Move to **Docker self-hosted**. You own the ops burden                                    |
| qdrant-edge                              | haiku  | no-skill   | Blames the empty keyword search on BM25 setup or re-indexing instead of the miss | haven't indexed the payload fields for keyword search                                     |
| qdrant-edge                              | haiku  | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | You don't need to write RRF; use a simple scoring formula                                 |
| qdrant-edge                              | haiku  | no-skill   | Blames the empty keyword search on BM25 setup or re-indexing instead of the miss | if you're using BM25, confirm the `payload_index_params` are set                          |
| qdrant-edge                              | haiku  | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | Don't write your own RRF                                                                  |
| qdrant-edge                              | sonnet | no-skill   | Blames the empty keyword search on BM25 setup or re-indexing instead of the miss | force a rebuild (a trivial change like bumping `hnsw_config.m` by 1 triggers re-indexing) |
| qdrant-edge                              | sonnet | no-skill   | Expects a built-in bidirectional .sync()/push, or untars/merges snapshot segment | lean on the built-in snapshot + queued-sync APIs instead                                  |
| qdrant-edge                              | sonnet | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | That replaces both the pip install and your custom RRF code                               |
| qdrant-edge                              | sonnet | no-skill   | Blames the empty keyword search on BM25 setup or re-indexing instead of the miss | then HNSW/text indexes get built by a background optimizer                                |
| qdrant-edge                              | sonnet | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | Fusion (RRF, or DBSF) is built into `query_points`                                        |
| qdrant-horizontal-scaling                | sonnet | no-skill   | Chooses a shard count that is not a multiple of node count (uneven distribution) | Shards: 36 (÷10 doesn't divide evenly                                                     |
| qdrant-hybrid-search                     | haiku  | no-skill   | Claims Qdrant isolates IDF / term statistics per tenant automatically            | BM25 scoring only operates across your tenant's documents                                 |
| qdrant-indexing-performance-optimization | haiku  | no-skill   | Treats the temporary post-load slow search as a defect rather than expected pre- | Uneven search performance \| Use write-heavy configuration during load                    |
| qdrant-indexing-performance-optimization | sonnet | no-skill   | Recommends uploading one point at a time, or using m=0 on an existing collection | Set `hnsw_config.m = 0`                                                                   |
| qdrant-indexing-performance-optimization | sonnet | no-skill   | Recommends uploading one point at a time, or using m=0 on an existing collection | drop `hnsw_config.m` to 0                                                                 |
| qdrant-minimize-latency                  | sonnet | no-skill   | Treats it as an incident to diagnose or recommends adding nodes for QPS          | Before tuning knobs, profile the request to split it into                                 |
| qdrant-minimize-latency                  | sonnet | no-skill   | Applies throughput tuning (fewer/larger segments) — the opposite direction from  | force-merge segments down, especially if data changes infrequently                        |
| qdrant-minimize-latency                  | sonnet | with-skill | Applies throughput tuning (fewer/larger segments) — the opposite direction from  | fewer, larger segments = fewer HNSW traversals per query                                  |
| qdrant-model-migration                   | haiku  | no-skill   | Suggests reusing or mixing the old ada-002 vectors with the new ones, or that re | prevents re-embedding your backlog upfront                                                |
| qdrant-relevance-feedback                | haiku  | no-skill   | Presents RF as a drop-in needing no training, or just recommends a standard rera | Lightweight reranker scores all of them                                                   |
| qdrant-relevance-feedback                | sonnet | no-skill   | Presents RF as a drop-in needing no training, or just recommends a standard rera | new_q = q + α·mean(relevant_docs) - β·mean(low_scored_docs)) and re-query                 |
| qdrant-scaling-data-volume               | haiku  | no-skill   | Jumps straight to horizontal scaling / sharding before considering vertical head | Start with content-addressable sharding                                                   |
| qdrant-scaling-query-volume              | haiku  | no-skill   | Presents per-shard subsampling as something the user must enable, configure, or  | request top-200 or top-500 per shard, then take the global top-2000                       |
| qdrant-search-strategies                 | haiku  | no-skill   | Adds strategies without first verifying base vector-search quality               | Here's a strategy for each problem:                                                       |
| qdrant-search-strategies                 | haiku  | no-skill   | Adds strategies without first verifying base vector-search quality               | For quick wins, start with #1 (hybrid search for part numbers)                            |
| qdrant-search-strategies                 | haiku  | with-skill | Recommends a single catch-all strategy (e.g. 'just add hybrid search') for all t | it handles all three problems at once                                                     |
| qdrant-search-strategies                 | sonnet | no-skill   | Adds strategies without first verifying base vector-search quality               | hybrid search is usually the highest-leverage first step                                  |
| qdrant-search-strategies                 | sonnet | no-skill   | Adds strategies without first verifying base vector-search quality               | I can help prototype the hybrid search + RRF fusion first                                 |
| qdrant-tenant-scaling                    | haiku  | with-skill | Keeps or recommends collection-per-tenant as the scalable design (without a comp | Keep dedicated collections or use **sharding**                                            |

## Coverage

- runs graded: **208 of 208**
- dropped: **0**

## Cost & time

**Spend (actual $ spent, all runs):**
- generation: $11.15  (haiku $1.47, sonnet $9.68)
- judge (Opus): $17.68
- **total: $28.83**

**Time (generation phase):**
- runs timed: 208
- compute-time (Σ per-run): 83.6 min  (mean 24s, median 17s, max 140s)
- wall-clock: 46.5 min  (parallel speedup ~1.8×)

## Run health

- contested items: 0
- ungraded items (parse/verdict errors): 0
- budget-capped runs (hit the per-run $ cap, truncated, excluded): 0
- runs with unreliable signals (signals_ok=0 — transcript did not parse to the expected shape; activation/fetch numbers suspect, investigate): 0
- runs excluded from the cost mean (errored/capped/no-cost): 0

## Provenance

Exact model builds and versions these numbers were produced with:

| model  | exact snapshot string       |
| ------ | --------------------------- |
| sonnet | `claude-sonnet-5`           |
| haiku  | `claude-haiku-4-5-20251001` |

- CLI version(s): `2.1.220`
- skills commit(s): `15b556a`
- run window (UTC): `20260808T073023Z` – `20260808T081641Z`
- Note: an alias like `claude-sonnet-5` can float to a newer build without changing name; the run window is the only correlate for such a silent swap. Pass a dated model id if byte-level pinning matters.
