# Qdrant Skills

## Project overview

Agent skills for [Qdrant](https://qdrant.tech) vector search, built on the [Agent Skills standard](https://agentskills.io/).

- **Repository:** `github.com/qdrant/skills`
- **Format:** Markdown SKILL.md files with YAML frontmatter
- **Compatible agents:** Claude Code, Cursor, OpenCode, OpenAI Codex, Pi

## Project structure

```
skills/
  qdrant-scaling/              # hub: links to sub-skills
    SKILL.md
    minimize-latency/          # leaf: actual guidance
      SKILL.md
    scaling-data-volume/       # hub: links to sub-skills
      SKILL.md
      horizontal-scaling/
      vertical-scaling/
      sliding-time-window/
      tenant-scaling/
    scaling-qps/
    scaling-query-volume/
  qdrant-performance-optimization/
    SKILL.md
    indexing-performance-optimization/
    memory-usage-optimization/
    search-speed-optimization/
  qdrant-search-quality/
    SKILL.md
    diagnosis/
    search-strategies/
      hybrid-search/
        search-types/
        combining-searches/
      relevance-feedback/
  qdrant-monitoring/
    SKILL.md
    debugging/
    setup/
  qdrant-clients-sdk/
  qdrant-deployment-options/
  qdrant-edge/
  qdrant-model-migration/
  qdrant-multitenancy/
  qdrant-sizing/
  qdrant-version-upgrade/
```

## Navigating skills locally

The same tree as the [published site](https://skills.qdrant.tech), reached by relative path instead of URL. Each `SKILL.md` links to its sub-skills, and those links are the navigation mechanism; follow them rather than assembling paths yourself.

- Read the `SKILL.md` for the relevant skill, then follow its relative links to go deeper. Skills nest up to four levels.
- If you do not have a link to the skill you need, do not guess the path. Glob `skills/**/SKILL.md` and grep the frontmatter `description` fields, which carry the `Use when` trigger phrases.
- When a tool summarizes a `SKILL.md`, preserve its Markdown links exactly as written. They are the only way to reach the deeper skills.

## Conventions

- **Skills** are passive knowledge. Hub skills declare `allowed-tools: [Read, Grep, Glob]`. Leaf skills omit `allowed-tools`.

### Skill anatomy

Every SKILL.md has YAML frontmatter (`name`, `description`) and a markdown body. Descriptions use `Use when` with exact user phrases for trigger matching. Sections are named by symptom, not feature. Each leaf skill ends with `## What NOT to Do`.

### Documentation links

All links point to `skills.qdrant.tech/md/documentation/`, inline at the end of bullets:

```
- Enable scalar quantization with `always_ram=true` [Scalar quantization](https://skills.qdrant.tech/md/documentation/manage-data/quantization/?s=scalar-quantization)
```
