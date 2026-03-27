# Qdrant Skills

A collection of [Agent Skills](https://agentskills.io/) for building with Qdrant vector search.

## Installing

These skills work with any agent that supports the Agent Skills standard, including Claude Code, OpenCode, OpenAI Codex, and Pi.

### Claude Code

Install using the [plugin marketplace](https://code.claude.com/docs/en/discover-plugins#add-from-github):

```
/plugin marketplace add qdrant/skills
```

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
| OpenCode | `~/.config/opencode/skill/` | [docs](https://opencode.ai/docs/skills/) |
| OpenAI Codex | `~/.codex/skills/` | [docs](https://developers.openai.com/codex/skills/) |
| Pi | `~/.pi/agent/skills/` | [docs](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#skills) |

## Commands

Commands are user-invocable slash commands that you explicitly call.

| Command | Description |
|---------|-------------|
| `/qdrant:setup-collection` | Create a collection with proper vector config, distance, and payload indexes |
| `/qdrant:hybrid-search` | Scaffold a dense+sparse prefetch query with RRF fusion |
| `/qdrant:add-multitenancy` | Add tenant isolation to an existing collection |
| `/qdrant:migrate-search` | Migrate deprecated `client.search()` calls to `query_points` |
| `/qdrant:connect` | Set up client connection for local or cloud |

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

## Resources

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [mcp-code-snippets](https://github.com/qdrant/mcp-code-snippets) - MCP server for searching Qdrant docs and code examples
- [mcp-server-qdrant](https://github.com/qdrant/mcp-server-qdrant) - Official Qdrant MCP server
