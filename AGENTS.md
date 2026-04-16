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
  qdrant-monitoring/
    SKILL.md
    debugging/
    setup/
  qdrant-clients-sdk/
  qdrant-deployment-options/
  qdrant-model-migration/
  qdrant-version-upgrade/
```

## Conventions

- **Skills** are passive knowledge. Hub skills declare `allowed-tools: [Read, Grep, Glob]`. Leaf skills omit `allowed-tools`.

### Skill anatomy

Every SKILL.md has YAML frontmatter (`name`, `description`) and a markdown body. Descriptions use `Use when` with exact user phrases for trigger matching. Sections are named by symptom, not feature. Each leaf skill ends with `## What NOT to Do`.

### Documentation links

All links point to `search.qdrant.tech/md/documentation/`, inline at the end of bullets:

```
- Enable scalar quantization with `always_ram=true` [Scalar quantization](https://search.qdrant.tech/md/documentation/manage-data/quantization/?s=scalar-quantization)
```
