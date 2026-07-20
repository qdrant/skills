# Qdrant Skills - Agent Skills for Qdrant Vector Search

<p align="center">
  <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://github.com/qdrant/qdrant/raw/master/docs/logo-dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="https://github.com/qdrant/qdrant/raw/master/docs/logo-light.svg">
      <img height="100" alt="Qdrant" src="https://github.com/qdrant/qdrant/raw/master/docs/logo.svg">
  </picture>
</p>

<p align="center">
    <b>Agent skills for building with Qdrant vector search</b>
</p>

Skills encode deep Qdrant knowledge so coding agents can make the engineering decisions that determine whether vector search works well: quantization, sharding, tenant isolation, hybrid search, model migration, and more.

## Philosophy

Skills are not documentation. Qdrant already has docs in markdown. Skills
answer "when?" and "why?", not "how?"

They are structured as the handbook of a Solutions Architect working on Qdrant:
given a problem, navigate to the exact place in the documentation where the
answer lives. No tutorials, no concept explanations. Only references and
minimal snippets where absolutely necessary.

## Disclaimer

These skills are under active development. Skill content and structure may change between versions as Qdrant evolves.

## Usage

Qdrant maintains a growing set of skills, and their content changes as Qdrant evolves. There are a few ways to give your agent access to them.

### Recommended: install the Qdrant Advisor

Install one skill — the **Qdrant Advisor** — and your agent always has the freshest, most relevant Qdrant guidance, with nothing to manage as the skills change:

```bash
npx skills add qdrant/skills/meta/qdrant-advisor
```

The Advisor ships no static content of its own. When you raise a Qdrant problem, it searches [skills.qdrant.tech](https://skills.qdrant.tech) live, traverses the skill hierarchy along the branch that matches your symptom, and grounds its diagnosis in the current, authoritative guidance, loading only the relevant context. Because it fetches fresh every session, you don't need to reinstall to stay current, and you don't have to remember a URL or hope the site is in the model's training data.

> **Using the claude.ai web app?** The Advisor can't fetch `skills.qdrant.tech` on its own when you are using the web app. You need to add `Use skills.qdrant.tech` to your prompt (refer to [Pass the URL directly](#alternative-pass-the-url-directly)).

### Alternative: pass the URL directly

If you'd rather not install anything, pass the URL of the skills site in your prompt. The agent fetches the skill relevant to your current problem:

```
Use skills.qdrant.tech
```

This keeps context focused, but you have to include the URL in every prompt.

### Offline: install the full skill set

If you want the skills available offline, or triggered automatically without the Advisor, install the complete set locally. See the [Installation](#installation) section.

## Quick Start

With the **Qdrant Advisor** installed, just ask your agent about Qdrant. The Advisor triggers automatically and loads the matching guidance live:

```
"I have 50M vectors on a single node and search is slow, should I add more nodes?"
→ Advisor loads the scaling guidance, recommends quantization and vertical scaling before adding nodes

"My search results are returning irrelevant matches"
→ Advisor loads the search-quality guidance, walks through diagnosis and search strategy options

"How do I switch from OpenAI embeddings to Cohere without downtime?"
→ Advisor loads the model-migration guidance for a zero-downtime switch with dual vectors
```

Prefer the URL method? Add `Use skills.qdrant.tech` to the same prompts:

```
"I have 50M vectors on a single node and search is slow, should I add more nodes? Use skills.qdrant.tech"

"My search results are returning irrelevant matches. Use skills.qdrant.tech"
```

## Skills

| Skill | Useful for |
|-------|------------|
| qdrant-clients-sdk | SDK setup, code examples, snippet search across Python, TypeScript, Rust, Go, .NET, Java |
| qdrant-scaling | Scaling decisions: data volume, QPS, latency, query volume, horizontal vs vertical |
| qdrant-performance-optimization | Search speed, memory usage, indexing performance |
| qdrant-search-quality | Diagnosing bad results, search strategies, hybrid search |
| qdrant-monitoring | Metrics, health checks, debugging optimizer and cluster issues |
| qdrant-multitenancy | Isolating multiple tenants within a Qdrant deployment: payload partitioning, tiered multitenancy, and region-based data isolation |
| qdrant-deployment-options | Choosing between local, self-hosted, cloud, and hybrid |
| qdrant-edge | Building on the embedded shard: server sync, on-device BM25, snapshots, reuse vs reimplement |
| qdrant-model-migration | Switching embedding models without downtime |
| qdrant-version-upgrade | Safe upgrade paths, compatibility guarantees, rolling upgrades |

## Installation

### Qdrant Advisor (recommended)

If you want a single, always-current skill instead of the full set, install only the **Qdrant Advisor**:

```bash
npx skills add qdrant/skills/meta/qdrant-advisor
```

This installs just the `qdrant-advisor` meta-skill. It ships no static content of its own, it loads the relevant Qdrant skills live from [skills.qdrant.tech](https://skills.qdrant.tech) on demand, so you always get the latest guidance without reinstalling. It is not part of the `npx skills add qdrant/skills` bundle.

### npx skills

Install using the [`npx skills`](https://skills.sh) CLI:

```bash
npx skills add qdrant/skills
```

### Claude Code

Add the marketplace, then install all Qdrant skills:

```
/plugin marketplace add qdrant/skills
/plugin install qdrant@qdrant
```

### Cursor

Install from the Cursor Marketplace or add manually via **Settings > Rules > Add Rule > Remote Rule (GitHub)** with `qdrant/skills`.

### Clone / Copy

Clone this repo and copy the skill folders into the appropriate directory for your agent:

| Agent | Skill Directory | Docs |
|-------|-----------------|------|
| Claude Code | `~/.claude/skills/` | [docs](https://code.claude.com/docs/en/skills) |
| Cursor | `.cursor/skills/` | [docs](https://docs.cursor.com/context/skills) |
| OpenCode | `~/.config/opencode/skill/` | [docs](https://opencode.ai/docs/skills/) |
| OpenAI Codex | `~/.codex/skills/` | [docs](https://developers.openai.com/codex/skills/) |
| Pi | `~/.pi/agent/skills/` | [docs](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#skills) |

## MCP Servers

For additional Qdrant context, pair skills with these MCP servers:

| Server | Purpose |
|--------|---------|
| [mcp-code-snippets](https://github.com/qdrant/mcp-code-snippets) | Search Qdrant docs and code examples across all SDKs |
| [mcp-server-qdrant](https://github.com/qdrant/mcp-server-qdrant) | Store and retrieve memories, manage collections directly |

## Getting Help

Found a bug or wrong advice in a skill? [Open an issue](https://github.com/qdrant/skills/issues/new) on GitHub and include:

- The skill name
- The prompt you gave your agent
- What the agent said vs what it should have said

## Contributing

If you are interested in contributing, follow the instructions in [CONTRIBUTING.md](./CONTRIBUTING.md).
