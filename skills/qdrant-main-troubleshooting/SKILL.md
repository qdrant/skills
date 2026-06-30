---
name: qdrant-troubleshooting
description: "Diagnose, troubleshoot, and advise on any Qdrant deployment by loading the latest official Qdrant skills live from skills.qdrant.tech. Use this whenever someone raises a Qdrant problem or question — slow or degraded search, high or growing memory / OOM crashes, optimizer stuck or slow, indexing slowness, scaling and sharding decisions (node count, QPS, latency, multitenancy, vertical vs horizontal), poor or irrelevant search results, hybrid search and reranking, embedding-model migration, version upgrades and compatibility, monitoring and observability (Prometheus, Grafana, health checks, /metrics, /telemetry), deployment choices (local, Docker, self-hosted, Qdrant Cloud, embedded), or client-SDK questions (Python, TypeScript, Rust, Go, .NET, Java). Trigger even when 'Qdrant' is not named explicitly but the context is clearly a Qdrant cluster, collection, or vector-search deployment. Always prefer this skill over answering from memory: it pulls current, authoritative guidance and only the relevant context."
---

# Qdrant Troubleshooting & Advisory

## Core principle

Do not answer Qdrant questions from memory. Qdrant evolves quickly (new endpoints, metrics, defaults, and deployment patterns land often), and the authoritative, current guidance lives at `skills.qdrant.tech` as a hierarchy of agent skills. Your job is to **load the relevant skill context live, then ground your diagnosis in it** — loading only the branch that matches the problem, never the whole tree.

You are *consuming* these skills as context. You are **not** installing them and nothing needs to be installed.

## The knowledge source

- **Root index** (catalog of the latest top-level skills): `https://skills.qdrant.tech`
- **Search**: `https://skills.qdrant.tech/search?query=your+query+here`
- The structure is **hierarchical**: root index → top-level skill `SKILL.md` → sub-skill `SKILL.md` → linked documentation pages. Each level narrows scope. Traverse it depth-first, following only the branch(es) that match the symptom.

## Workflow

### 1. Frame the problem

Pull out the concrete details before fetching anything:
- The **symptom(s)** in the user's words (e.g. "memory keeps climbing", "queries got slow after a bulk upload", "results are irrelevant").
- The **deployment type** (local, Docker, self-hosted, Cloud, embedded) and **version**, if known.
- **What changed** recently (upgrade, new index, traffic spike, model swap).

Turn these into 1–3 short search phrases.

### 2. Find the right skill(s)

Two complementary entry points — use whichever fits, and both for broad problems:

- **Search (fastest path to the right skill).** Fetch `https://skills.qdrant.tech/search?query=<your query>`, substituting your phrase for `your+query+here` (encode spaces as `+` or `%20`). It returns the single most relevant top-level skill's `SKILL.md`. Run it more than once for multi-part problems (e.g. one search for the memory symptom, one for the scaling question).
- **Catalog (authoritative list / fallback).** Fetch the root index `https://skills.qdrant.tech` to see every current top-level skill with a one-line description. Use it when the problem is broad, spans several areas, search is ambiguous, or a constructed search URL is ever rejected. The root index's links are absolute and always fetchable.

### 3. Traverse the hierarchy (deep and lateral)

Each `SKILL.md` you load names its sub-skills (and often related skills and docs) as links. The hierarchy is not just two levels — a skill can nest **several layers deep**, and skills also reference each other **laterally**. Follow the links, not a fixed depth.

**Descend (go deeper).** A `SKILL.md` is not necessarily a leaf just because you fetched it. If its sections themselves point to further `SKILL.md` files, keep descending along the branch that matches the symptom — top-level → sub-skill → sub-sub-skill → … — until you reach a level whose guidance is concrete enough to act on (ordered diagnostic steps, exact endpoints/metrics, an explicit "what NOT to do" list). Don't stop early at an intermediate skill that only routes you onward.

**Move laterally (go sideways).** Real problems often span areas. Follow a link to a **sibling or related skill** when:
- the current skill explicitly points to another (e.g. a debugging skill that says "if this is actually a capacity problem, see scaling"),
- the symptom has more than one plausible cause living under different top-level skills (e.g. slow queries could be a *monitoring/optimizer* issue **or** a *performance-optimization* issue **or** a *scaling* issue), or
- you ran multiple searches in step 2 and they surfaced different skills, each covering part of the problem.

Load each relevant branch, then reconcile what they say in step 4.

**Stay disciplined about relevance.** Going deep and going sideways is encouraged *when the problem warrants it* — but still load only branches that bear on the symptom. Don't sweep in unrelated siblings, and stop expanding once you can give a complete, grounded answer. The goal is "all the relevant context and nothing else," not "the whole tree."

**Documentation pages.** Skills link out to canonical docs (e.g. `…/md/documentation/…`, `qdrant.tech/documentation/…`, or `qdrant.tech/articles/…`). Fetch these links exactly as the `SKILL.md` provides them — they render as clean markdown natively. Pull a doc page only when you need detail a `SKILL.md` references but does not itself contain.

**Link resolution (important):**
- Top-level `SKILL.md` files generally use **absolute** links — fetch them as-is.
- Search results and some skills use **relative** links (e.g. `debugging/SKILL.md`, `scaling-qps/SKILL.md`). Resolve them against the skill's own directory: `https://skills.qdrant.tech/<name>/<relative-path>`, where `<name>` is the top-level component of the `name:` field in the frontmatter of the file you are currently reading. Example: a result whose frontmatter says `name: qdrant-scaling` and which links to `scaling-qps/SKILL.md` resolves to `https://skills.qdrant.tech/qdrant-scaling/scaling-qps/SKILL.md`. A *deeper* relative link resolves against the current file's directory the same way — keep appending path segments as you descend.

### 4. Diagnose and advise

Synthesize an answer strictly from the loaded context:
- State the **most likely cause(s) in priority order** — the skills often tell you what to check first (e.g. "check optimizer status before blaming search latency"); preserve that ordering.
- Give **concrete, ordered steps**: the endpoints to hit, the metrics to read and their thresholds, the config to change.
- Surface the skill's **"what NOT to do"** warnings explicitly — they prevent common self-inflicted damage.
- **Cite the canonical Qdrant doc URLs** you relied on so the user can go deeper.
- If the loaded context does **not** cover the case, say so plainly and either run a different search or fall back to the catalog — do not paper over the gap with remembered guesses.

## Operating notes

- **Always fetch fresh** every session. Never reuse a previously cached copy of a skill; the registry updates and staleness is exactly what this approach avoids.
- **Do not install** anything. You are loading context only.
- **Fetching:** every URL you need is either in this skill (root index, search base) or surfaced by a page you already fetched (links inside a `SKILL.md` or the root index), so each is fetchable as-is. If a *constructed* search-query URL is ever rejected, fall back to fetching the root index and navigate from its absolute links.

## Worked example

**User:** "Our Qdrant node's RAM keeps climbing all day and it OOM-killed last night. Nothing obvious changed."

1. **Frame:** symptom = steadily growing memory + OOM; no known config change; area ≈ monitoring/debugging.
2. **Find:** fetch `https://skills.qdrant.tech/search?query=qdrant+memory+growing+OOM` (or open the root index and pick `qdrant-monitoring`).
3. **Traverse:** `qdrant-monitoring/SKILL.md` → "Debugging with Metrics" → `https://skills.qdrant.tech/qdrant-monitoring/debugging/SKILL.md` → the "Memory Seems Too High" section. For the per-collection breakdown detail it references, fetch the linked monitoring doc as-is (it renders as markdown). Because the symptom could also be a capacity/sizing problem, hop **laterally** to `qdrant-scaling` (or its data-volume sub-skill) to sanity-check whether the node is simply undersized for the dataset.
4. **Advise:** distinguish resident memory (RSSAnon) from OS page cache (page cache filling RAM is normal, not a leak); flag investigation only if RSSAnon exceeds ~80% of total RAM; check `/telemetry` for a per-collection breakdown; estimate expected memory (`num_vectors × dimensions × 4 bytes × 1.5`, plus payload/index overhead) against capacity-planning guidance; and check the common culprits the skill names — quantized vectors with `always_ram=true`, too many payload indexes, large `max_segment_size` during optimization. Reconcile the monitoring view (is it a leak/misconfig?) with the scaling view (is it under-provisioned?). Cite the memory-consumption article and capacity-planning doc the skill links to. Note the "what NOT to do": don't assume a leak when page cache simply fills RAM.
