# Qdrant Advisor

Diagnose, troubleshoot, and advise on Qdrant deployments from your coding agent. The Advisor skill loads the latest official Qdrant skills live from [skills.qdrant.tech](https://skills.qdrant.tech), follows only the branch that matches your problem, and grounds its answer in current guidance instead of memory. It covers slow or degraded search, memory and OOM issues, indexing, scaling and sharding, search quality, hybrid search, model migration, version upgrades, monitoring, deployment choices, and client SDKs.

## Install

```
/plugin marketplace add qdrant/skills
/plugin install qdrant-advisor@qdrant
```

## What the plugin does and connects to

The plugin has no scripts, hooks, or commands. It contains one skill and two remote MCP server references.

- **Skill (`qdrant-advisor`)**: fetches pages from `https://skills.qdrant.tech` and the Qdrant documentation links that those pages reference. It sends the search phrases it builds from your question to skills.qdrant.tech. It does not send other data.
- **Qdrant Docs MCP** (`https://search.qdrant.tech/mcp`): read-only search of Qdrant documentation, articles, and code snippets. No sign-in is required.
- **Qdrant Cloud MCP** (`https://api.cloud.qdrant.io/mcp`): manages Qdrant Cloud clusters, backups, access, and billing. It uses OAuth, so you sign in through `/mcp` and select `qdrant-cloud`. It can change or delete clusters in your account, so the skill asks before making any change. It cannot read or write collection data.

The plugin does not store data or read credentials from your environment.

## Source

The skill is maintained in the [qdrant/skills repository](https://github.com/qdrant/skills/tree/main/meta/qdrant-advisor) and copied into this plugin by a sync script. Licensed under Apache-2.0.
