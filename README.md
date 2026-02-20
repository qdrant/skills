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

| Skill | Language | Transport | Useful for |
|-------|----------|-----------|------------|
| qdrant-python | Python | REST (6333) | `qdrant-client` SDK: query_points, filtering, hybrid search, multi-tenancy, gotchas |
| qdrant-typescript | TypeScript/JS | REST (6333) | `@qdrant/js-client-rest`: query, plain-object filters, hybrid search, named vectors |
| qdrant-rust | Rust | gRPC (6334) | `qdrant-client` crate: builders, query, upsert, async patterns, gotchas |
| qdrant-go | Go | gRPC (6334) | `go-client`: protobuf types, constructor helpers, PtrOf patterns, gotchas |
| qdrant-dotnet | C# / .NET | gRPC (6334) | `Qdrant.Client` NuGet: operator overload filters, async, implicit conversions |
| qdrant-java | Java | gRPC (6334) | `io.qdrant:client`: factory classes, ListenableFuture, builder pattern, gotchas |

## References

Each skill includes a `references/` directory with detailed supplemental docs that agents can load on demand:

| Skill | Reference | Contents |
|-------|-----------|----------|
| qdrant-python | `references/filtering.md` | All filter condition types, nested filters, geo, datetime |
| qdrant-python | `references/migration-guide.md` | Old-to-new API migration table |
| qdrant-rust | `references/builders.md` | Comprehensive builder API reference for all operations |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/start-qdrant.sh` | Pull and run a local Qdrant Docker container |

Usage:

```bash
bash scripts/start-qdrant.sh          # latest version
bash scripts/start-qdrant.sh v1.13.0  # specific version
```

## Validation

Run the Makefile targets to check skill definitions:

```bash
make validate  # run skills-ref validator (requires npm install -g skills-ref)
make lint      # basic frontmatter checks
```

## Resources

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [mcp-code-snippets](https://github.com/qdrant/mcp-code-snippets) - MCP server for searching Qdrant docs and code examples
- [mcp-server-qdrant](https://github.com/qdrant/mcp-server-qdrant) - Official Qdrant MCP server
