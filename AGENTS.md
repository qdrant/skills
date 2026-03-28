# Qdrant Skills

## Project overview

Agent skills for [Qdrant](https://qdrant.tech) vector search, built on the [Agent Skills standard](https://agentskills.io/).

- **Repository:** `github.com/qdrant/skills`
- **Format:** Markdown SKILL.md files with YAML frontmatter
- **Compatible agents:** Claude Code, OpenCode, OpenAI Codex, Pi

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
  qdrant-search-quality/
  qdrant-monitoring/
  qdrant-clients-sdk/
  qdrant-deployment-options/
  qdrant-model-migration/
  qdrant-version-upgrade/
commands/
  setup-collection.md
  hybrid-search.md
  add-multitenancy.md
  migrate-search.md
  connect.md
scripts/
  validate_skills.py           # skill linter
```

## Verification

Run the skill linter:

```bash
python3 scripts/validate_skills.py
```

## Conventions

### Skills vs commands

- **Skills** are passive knowledge. Hub skills declare `allowed-tools: [Read, Grep, Glob]`. Leaf skills omit `allowed-tools`.
- **Commands** are user-invoked actions with `allowed-tools: [Read, Glob, Grep, Bash, Write, Edit]`.

### Skill anatomy

Every SKILL.md has YAML frontmatter (`name`, `description`) and a markdown body. Descriptions use `Use when` with exact user phrases for trigger matching. Sections are named by symptom, not feature. Each leaf skill ends with `## What NOT to Do`.

### Documentation links

All links point to `qdrant.tech/documentation/`, inline at the end of bullets:

```
- Enable scalar quantization with `always_ram=true` [Scalar quantization](https://qdrant.tech/documentation/guides/quantization/#scalar-quantization)
```
