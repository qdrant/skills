# Weekly Skill Scorecard — 20260929T101319Z

## Lift per model (with-skill − no-skill)

| model  | must_coverage no→with | must lift ± SE | 95% CI != 0? | Δbonus | Δavoid | Δcost ($) | Δturns |
| ------ | --------------------- | -------------- | ------------ | ------ | ------ | --------- | ------ |
| sonnet | 0.651 → 0.882         | +0.231 ± 0.055 | yes          | +0.460 | -0.08  | -0.0014   | +1.8   |
| haiku  | 0.211 → 0.788         | +0.577 ± 0.054 | yes          | +0.353 | -0.26  | +0.0018   | +2.7   |

_± SE is one within-week standard error of the paired per-prompt must-coverage lift — this week's sampling uncertainty (finite prompt set + run/judge noise), **not** between-week drift. '≠ 0?' asks whether the 95% CI (t·SE) excludes zero: 'no' means don't act on this lift yet. Δbonus/Δavoid appear only when the skill changed bonus depth or introduced/removed a violation. Δcost/Δturns are within-model only; negative = cheaper/sooner. Note: turns counts all conversation messages, including tool-result messages, not just the model's own turns. Reported, not gated._

## Week-over-week lift delta

**Will be computed after four runs.** (this is run 2 of 4; a delta needs prior runs to estimate the between-week noise floor. This week's own sampling uncertainty is in the lift table above as ± SE.)

## Per-cell metrics

| model  | condition  | must_cov | bonus_rate | avoid_viol | composite | mean cost | mean turns | n  |
| ------ | ---------- | -------- | ---------- | ---------- | --------- | --------- | ---------- | -- |
| sonnet | no-skill   | 0.651    | 0.259      | 0.10       | 0.640     | 0.0371    | 1.5        | 31 |
| sonnet | with-skill | 0.882    | 0.719      | 0.02       | 0.892     | 0.0357    | 3.4        | 31 |
| haiku  | no-skill   | 0.211    | 0.085      | 0.35       | 0.194     | 0.0170    | 1.1        | 31 |
| haiku  | with-skill | 0.788    | 0.438      | 0.10       | 0.776     | 0.0188    | 3.7        | 31 |

## Per-prompt (must_coverage; with-skill lift)

| prompt                                       | model  | must no→with  | must lift | comp no→with  |
| -------------------------------------------- | ------ | ------------- | --------- | ------------- |
| qdrant-clients-sdk                           | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-clients-sdk                           | haiku  | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-deployment-options                    | sonnet | 0.833 → 1.000 | +0.167    | 0.833 → 1.000 |
| qdrant-deployment-options                    | haiku  | 0.333 → 1.000 | +0.667    | 0.233 → 1.000 |
| qdrant-edge                                  | sonnet | 0.700 → 1.000 | +0.300    | 0.483 → 1.000 |
| qdrant-edge                                  | haiku  | 0.000 → 0.900 | +0.900    | 0.000 → 0.917 |
| qdrant-horizontal-scaling                    | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-horizontal-scaling                    | haiku  | 0.750 → 1.000 | +0.250    | 0.750 → 1.000 |
| qdrant-hybrid-cloud-setup                    | sonnet | 0.500 → 1.000 | +0.500    | 0.533 → 1.000 |
| qdrant-hybrid-cloud-setup                    | haiku  | 0.200 → 0.900 | +0.700    | 0.100 → 0.792 |
| qdrant-hybrid-cloud-setup-agent-connectivity | sonnet | 0.500 → 0.500 | +0.000    | 0.375 → 0.567 |
| qdrant-hybrid-cloud-setup-agent-connectivity | haiku  | 0.000 → 0.667 | +0.667    | 0.000 → 0.700 |
| qdrant-hybrid-search                         | sonnet | 0.500 → 0.250 | -0.250    | 0.510 → 0.270 |
| qdrant-hybrid-search                         | haiku  | 0.000 → 0.375 | +0.375    | 0.000 → 0.375 |
| qdrant-hybrid-search-combining               | sonnet | 0.400 → 1.000 | +0.600    | 0.400 → 1.000 |
| qdrant-hybrid-search-combining               | haiku  | 0.200 → 0.600 | +0.400    | 0.200 → 0.475 |
| qdrant-hybrid-search-prefetches              | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-hybrid-search-prefetches              | haiku  | 0.875 → 1.000 | +0.125    | 0.875 → 1.000 |
| qdrant-indexing-performance-optimization     | sonnet | 0.875 → 0.875 | +0.000    | 0.875 → 0.925 |
| qdrant-indexing-performance-optimization     | haiku  | 0.125 → 0.625 | +0.500    | 0.125 → 0.675 |
| qdrant-memory-usage-optimization             | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-memory-usage-optimization             | haiku  | 0.000 → 1.000 | +1.000    | 0.033 → 1.000 |
| qdrant-migration-tool                        | sonnet | 0.250 → 0.750 | +0.500    | 0.125 → 0.850 |
| qdrant-migration-tool                        | haiku  | 0.000 → 0.875 | +0.875    | 0.000 → 0.875 |
| qdrant-minimize-latency                      | sonnet | 0.833 → 1.000 | +0.167    | 0.708 → 0.875 |
| qdrant-minimize-latency                      | haiku  | 0.333 → 1.000 | +0.667    | 0.333 → 1.000 |
| qdrant-model-migration                       | sonnet | 0.625 → 1.000 | +0.375    | 0.625 → 1.000 |
| qdrant-model-migration                       | haiku  | 0.000 → 0.750 | +0.750    | 0.000 → 0.775 |
| qdrant-monitoring                            | sonnet | 0.667 → 1.000 | +0.333    | 0.717 → 1.000 |
| qdrant-monitoring                            | haiku  | 0.333 → 1.000 | +0.667    | 0.333 → 1.000 |
| qdrant-monitoring-debugging                  | sonnet | 0.875 → 1.000 | +0.125    | 0.875 → 1.000 |
| qdrant-monitoring-debugging                  | haiku  | 0.250 → 1.000 | +0.750    | 0.250 → 1.000 |
| qdrant-monitoring-setup                      | sonnet | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-monitoring-setup                      | haiku  | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-multitenancy                          | sonnet | 0.700 → 0.800 | +0.100    | 0.725 → 0.875 |
| qdrant-multitenancy                          | haiku  | 0.400 → 0.700 | +0.300    | 0.413 → 0.725 |
| qdrant-performance-optimization              | sonnet | 0.667 → 1.000 | +0.333    | 0.717 → 1.000 |
| qdrant-performance-optimization              | haiku  | 0.333 → 0.333 | +0.000    | 0.333 → 0.333 |
| qdrant-relevance-feedback                    | sonnet | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-relevance-feedback                    | haiku  | 0.000 → 0.875 | +0.875    | 0.000 → 0.900 |
| qdrant-scaling-data-volume                   | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-scaling-data-volume                   | haiku  | 0.333 → 0.667 | +0.333    | 0.358 → 0.717 |
| qdrant-scaling-qps                           | sonnet | 0.333 → 0.333 | +0.000    | 0.333 → 0.333 |
| qdrant-scaling-qps                           | haiku  | 0.167 → 0.500 | +0.333    | 0.167 → 0.500 |
| qdrant-scaling-query-volume                  | sonnet | 0.000 → 0.833 | +0.833    | 0.000 → 0.883 |
| qdrant-scaling-query-volume                  | haiku  | 0.000 → 0.500 | +0.500    | 0.000 → 0.525 |
| qdrant-search-quality-diagnosis              | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-search-quality-diagnosis              | haiku  | 0.500 → 1.000 | +0.500    | 0.500 → 1.000 |
| qdrant-search-speed-optimization             | sonnet | 0.667 → 1.000 | +0.333    | 0.692 → 1.000 |
| qdrant-search-speed-optimization             | haiku  | 0.167 → 0.333 | +0.167    | 0.167 → 0.333 |
| qdrant-search-strategies                     | sonnet | 1.000 → 1.000 | +0.000    | 1.000 → 1.000 |
| qdrant-search-strategies                     | haiku  | 0.500 → 1.000 | +0.500    | 0.550 → 1.000 |
| qdrant-sizing                                | sonnet | 1.000 → 1.000 | +0.000    | 0.908 → 1.000 |
| qdrant-sizing                                | haiku  | 0.417 → 0.833 | +0.417    | 0.033 → 0.417 |
| qdrant-sliding-time-window                   | sonnet | 0.333 → 0.500 | +0.167    | 0.367 → 0.533 |
| qdrant-sliding-time-window                   | haiku  | 0.000 → 0.000 | +0.000    | 0.017 → 0.033 |
| qdrant-tenant-scaling                        | sonnet | 0.750 → 1.000 | +0.250    | 0.825 → 1.000 |
| qdrant-tenant-scaling                        | haiku  | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-version-upgrade                       | sonnet | 0.667 → 1.000 | +0.333    | 0.667 → 1.000 |
| qdrant-version-upgrade                       | haiku  | 0.000 → 1.000 | +1.000    | 0.000 → 1.000 |
| qdrant-vertical-scaling                      | sonnet | 0.500 → 0.500 | +0.000    | 0.533 → 0.533 |
| qdrant-vertical-scaling                      | haiku  | 0.333 → 1.000 | +0.667    | 0.258 → 1.000 |

## Activation / trigger misses

- with-skill runs: **124**
- **trigger misses** (activation=none — skill present but never reached): **23**
- lift sourced from the published site (activation=web_fetch, not the local SKILL.md): **0**

| prompt                                       | activations (with-skill)  | reached leaf |
| -------------------------------------------- | ------------------------- | ------------ |
| qdrant-clients-sdk                           | skill_tool×4              | 0/4          |
| qdrant-deployment-options                    | skill_tool×4              | 0/4          |
| qdrant-edge                                  | skill_tool×4              | 0/4          |
| qdrant-horizontal-scaling                    | skill_tool×4              | 4/4          |
| qdrant-hybrid-cloud-setup                    | skill_tool×4              | 0/4          |
| qdrant-hybrid-cloud-setup-agent-connectivity | skill_tool×4              | 0/4          |
| qdrant-hybrid-search                         | none×3, skill_tool×1      | 1/4          |
| qdrant-hybrid-search-combining               | skill_tool×4              | 4/4          |
| qdrant-hybrid-search-prefetches              | none×2, skill_tool×2      | 2/4          |
| qdrant-indexing-performance-optimization     | skill_tool×4              | 4/4          |
| qdrant-memory-usage-optimization             | skill_tool×4              | 4/4          |
| qdrant-migration-tool                        | skill_tool×4              | 0/4          |
| qdrant-minimize-latency                      | none×2, skill_tool×2      | 2/4          |
| qdrant-model-migration                       | skill_tool×4              | 0/4          |
| qdrant-monitoring                            | skill_tool×4              | 0/4          |
| qdrant-monitoring-debugging                  | skill_tool×4              | 4/4          |
| qdrant-monitoring-setup                      | skill_tool×4              | 4/4          |
| qdrant-multitenancy                          | skill_tool×4              | 0/4          |
| qdrant-performance-optimization              | none×2, skill_tool×2      | 0/4          |
| qdrant-relevance-feedback                    | skill_tool×4              | 4/4          |
| qdrant-scaling-data-volume                   | none×2, skill_tool×2      | 2/4          |
| qdrant-scaling-qps                           | none×3, skill_tool×1      | 1/4          |
| qdrant-scaling-query-volume                  | skill_tool×4              | 4/4          |
| qdrant-search-quality-diagnosis              | skill_tool×4              | 4/4          |
| qdrant-search-speed-optimization             | none×2, skill_tool×2      | 2/4          |
| qdrant-search-strategies                     | none×1, skill_tool×3      | 3/4          |
| qdrant-sizing                                | skill_tool×4              | 0/4          |
| qdrant-sliding-time-window                   | none×4  ⚠ never triggered | 0/4          |
| qdrant-tenant-scaling                        | skill_tool×4              | 4/4          |
| qdrant-version-upgrade                       | skill_tool×4              | 0/4          |
| qdrant-vertical-scaling                      | none×2, skill_tool×2      | 2/4          |

## Lift caveat — baseline self-served the skill

- no-skill runs that fetched `skills.qdrant.tech`: **0 of 124**

## `avoid` violations (most damaging failures)

| prompt                                       | model  | condition  | violated item                                                                    | evidence                                                                                               |
| -------------------------------------------- | ------ | ---------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| qdrant-deployment-options                    | haiku  | no-skill   | Recommends self-managed distributed Docker as the production target despite the  | Single Qdrant instance on a cheap EU VPS                                                               |
| qdrant-edge                                  | haiku  | no-skill   | Blames the empty keyword search on BM25 setup or re-indexing instead of the miss | Keyword search (BM25) in Qdrant requires explicit text field indexing.                                 |
| qdrant-edge                                  | haiku  | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | Instead, use Qdrant's `SearchRequest` with `fusion: RRFType` to blend vector + BM25                    |
| qdrant-edge                                  | haiku  | no-skill   | Blames the empty keyword search on BM25 setup or re-indexing instead of the miss | you probably need to explicitly trigger index creation or wait for it                                  |
| qdrant-edge                                  | haiku  | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | BM25 + custom RRF is likely overkill                                                                   |
| qdrant-edge                                  | sonnet | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | fused inside one `shard.query(...)`, with no Python-side merge                                         |
| qdrant-edge                                  | sonnet | no-skill   | Drops the custom fusion because "Edge handles hybrid," or swaps embed_document/e | So you shouldn't need to write RRF yourself.                                                           |
| qdrant-hybrid-cloud-setup                    | haiku  | no-skill   | Tells the user the existing NFS StorageClass or nightly volume backups will work | NFS works for Qdrant, but understand the throughput limits                                             |
| qdrant-hybrid-cloud-setup                    | haiku  | with-skill | Tells the user the existing NFS StorageClass or nightly volume backups will work | your nightly volume backups become your only safety net                                                |
| qdrant-hybrid-cloud-setup-agent-connectivity | haiku  | no-skill   | Blames the pods themselves or suggests recreating the whole environment before c | In the Qdrant Cloud console, delete the stuck environment entirely                                     |
| qdrant-hybrid-cloud-setup-agent-connectivity | haiku  | no-skill   | Claims the namespace or other settings can't be changed, or that the fix require | Nuke the old install and regenerate                                                                    |
| qdrant-hybrid-cloud-setup-agent-connectivity | haiku  | no-skill   | Blames the pods themselves or suggests recreating the whole environment before c | Or, nuke it cleanly: remove the namespace (`kubectl delete ns qdrant-cloud`)                           |
| qdrant-hybrid-cloud-setup-agent-connectivity | sonnet | no-skill   | Claims the namespace or other settings can't be changed, or that the fix require | Have your teammate or the console discard or delete the stuck environment                              |
| qdrant-hybrid-search-combining               | haiku  | with-skill | Recommends late-interaction reranking without evaluating cheaper analogues (e.g. | A cross-encoder or late-interaction reranker (ColBERT, ColPali) reranks the pooled candidates          |
| qdrant-migration-tool                        | haiku  | no-skill   | Assumes the collection is auto-created for Weaviate, or attributes the empty res | Silent data loss in the migration script: The code is catching/ignoring write errors                   |
| qdrant-migration-tool                        | haiku  | no-skill   | Assumes the collection is auto-created for Weaviate, or attributes the empty res | Batch/commit logic** — writes queued but never flushed                                                 |
| qdrant-migration-tool                        | sonnet | no-skill   | Assumes the collection is auto-created for Weaviate, or attributes the empty res | A missing `await`, an unjoined thread pool, or a buffer that isn't closed                              |
| qdrant-minimize-latency                      | sonnet | no-skill   | Applies throughput tuning (fewer/larger segments) — the opposite direction from  | Force-merge or compact to fewer, larger segments.                                                      |
| qdrant-minimize-latency                      | sonnet | with-skill | Applies throughput tuning (fewer/larger segments) — the opposite direction from  | Merge into fewer, larger segments to cut per-segment overhead.                                         |
| qdrant-relevance-feedback                    | haiku  | no-skill   | Presents RF as a drop-in needing no training, or just recommends a standard rera | a lightweight ranker like ColBERT on the merged top-k (option 2)                                       |
| qdrant-scaling-query-volume                  | haiku  | no-skill   | Presents per-shard subsampling as something the user must enable, configure, or  | Try requesting `limit: 500` per shard initially instead of 2,000, then measure.                        |
| qdrant-sizing                                | haiku  | no-skill   | States a specific CPU core count as a firm recommendation instead of noting that | ~50-80 QPS per core \| **8-10 cores** (modern generation)                                              |
| qdrant-sizing                                | haiku  | no-skill   | States a specific quantization recall-loss percentage without evidence or benchm | Scalar quantization typically causes **2-5% recall loss**                                              |
| qdrant-sizing                                | haiku  | no-skill   | States a specific CPU core count as a firm recommendation instead of noting that | 16 cores handles 500 QPS comfortably                                                                   |
| qdrant-sizing                                | haiku  | no-skill   | States a specific quantization recall-loss percentage without evidence or benchm | Recall loss \| 1–3% with proper calibration                                                            |
| qdrant-sizing                                | haiku  | with-skill | States a specific CPU core count as a firm recommendation instead of noting that | **16+ CPU cores per node** (64-bit, 2+ GHz)                                                            |
| qdrant-sizing                                | haiku  | with-skill | States a specific quantization recall-loss percentage without evidence or benchm | Recall impact: typically 1–3% loss with SQ on 768-d vectors                                            |
| qdrant-sizing                                | haiku  | with-skill | States a specific CPU core count as a firm recommendation instead of noting that | p99 100ms latency on HNSW requires ~8–12 CPU cores per node                                            |
| qdrant-sizing                                | haiku  | with-skill | States a specific quantization recall-loss percentage without evidence or benchm | Typical recall loss: **1–5%** with scalar quantization                                                 |
| qdrant-sizing                                | sonnet | no-skill   | States a specific quantization recall-loss percentage without evidence or benchm | Scalar int8 typically loses well under 1% recall@10 on normalized text embeddings                      |
| qdrant-tenant-scaling                        | haiku  | no-skill   | Keeps or recommends collection-per-tenant as the scalable design (without a comp | Large tenants (top 5–10% of customers): keep in dedicated collections to prevent noisy neighbor issues |
| qdrant-tenant-scaling                        | haiku  | no-skill   | Omits is_tenant=true on the tenant index (kills sequential-read performance) or  | shared collections grouped by size tier with tenant-id filtering at query time                         |
| qdrant-tenant-scaling                        | haiku  | no-skill   | Keeps or recommends collection-per-tenant as the scalable design (without a comp | Identify your top 50-100 largest customers by vector count, give them dedicated collections.           |
| qdrant-tenant-scaling                        | haiku  | no-skill   | Omits is_tenant=true on the tenant index (kills sequential-read performance) or  | add a `tenant_id` field, filter all queries by tenant                                                  |
| qdrant-vertical-scaling                      | haiku  | no-skill   | Treats the 80% RAM threshold as a soft/gradual limit rather than a performance c | You have ~20 GB buffer before things get really bad                                                    |

## Coverage

- runs graded: **248 of 248**
- dropped: **0**

## Cost & time

**Spend (actual $ spent, all runs):**
- generation: $6.73  (haiku $2.22, sonnet $4.51)
- judge (Opus): $11.90
- **total: $18.63**

**Time (generation phase):**
- runs timed: 248
- compute-time (Σ per-run): 72.2 min  (mean 17s, median 15s, max 142s)
- wall-clock: 40.4 min  (parallel speedup ~1.8×)

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
| sonnet | `claude-sonnet-5-5`         |
| haiku  | `claude-haiku-4-5-20251001` |

- CLI version(s): `2.1.284`
- skills commit(s): `a4cf493`
- run window (UTC): `20260929T101319Z` – `20260929T105326Z`
- Note: an alias like `claude-sonnet-5` can float to a newer build without changing name; the run window is the only correlate for such a silent swap. Pass a dated model id if byte-level pinning matters.
