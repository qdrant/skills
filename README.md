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

## Skills

| Skill | Useful for |
|-------|------------|
| qdrant-python | Python SDK best practices: search, filtering, hybrid search, multi-tenancy, gotchas |
| qdrant-rust | Rust client best practices: gRPC setup, builders, query, upsert, gotchas |

## Resources

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [mcp-code-snippets](https://github.com/qdrant/mcp-code-snippets) - MCP server for searching Qdrant docs and code examples
- [mcp-server-qdrant](https://github.com/qdrant/mcp-server-qdrant) - Official Qdrant MCP server
