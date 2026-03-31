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


## Disclaimer

These skills are under active development. Skill content and structure may change between versions as Qdrant evolves.


## Installation

### Claude Code

Install using the [plugin marketplace](https://code.claude.com/docs/en/discover-plugins#add-from-github):

```
/plugin marketplace add qdrant/skills
```

### Cursor

Install from the Cursor Marketplace or add manually via **Settings > Rules > Add Rule > Remote Rule (GitHub)** with `qdrant/skills`.

### npx skills

Install using the [`npx skills`](https://skills.sh) CLI:

```
npx skills add https://github.com/qdrant/skills
```

### Clone / Copy

Clone this repo and copy the skill folders into the appropriate directory for your agent:

| Agent | Skill Directory | Docs |
|-------|-----------------|------|
| Claude Code | `~/.claude/skills/` | [docs](https://code.claude.com/docs/en/skills) |
| Cursor | `.cursor/skills/` | [docs](https://docs.cursor.com/context/skills) |
| OpenCode | `~/.config/opencode/skill/` | [docs](https://opencode.ai/docs/skills/) |
| OpenAI Codex | `~/.codex/skills/` | [docs](https://developers.openai.com/codex/skills/) |
| Pi | `~/.pi/agent/skills/` | [docs](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#skills) |


## Quick Start

After installing, just ask your agent about Qdrant. Skills are triggered automatically when your question matches their description.

```
"I have 50M vectors on a single node and search is slow, should I add more nodes?"
→ qdrant-scaling skill activates, recommends quantization and vertical scaling before adding nodes

"My search results are returning irrelevant matches"
→ qdrant-search-quality skill activates, walks through diagnosis and search strategy options

"How do I switch from OpenAI embeddings to Cohere without downtime?"
→ qdrant-model-migration skill activates, guides zero-downtime migration with dual vectors
```


## Skills

Skills are triggered automatically when your question matches their description.

| Skill | Useful for |
|-------|------------|
| qdrant-clients-sdk | SDK setup, code examples, snippet search across Python, TypeScript, Rust, Go, .NET, Java |
| qdrant-scaling | Scaling decisions: data volume, QPS, latency, query volume, horizontal vs vertical |
| qdrant-performance-optimization | Search speed, memory usage, indexing performance |
| qdrant-search-quality | Diagnosing bad results, search strategies, hybrid search |
| qdrant-monitoring | Metrics, health checks, debugging optimizer and cluster issues |
| qdrant-deployment-options | Choosing between local, self-hosted, cloud, and hybrid |
| qdrant-model-migration | Switching embedding models without downtime |
| qdrant-version-upgrade | Safe upgrade paths, compatibility guarantees, rolling upgrades |


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
