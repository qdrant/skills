# Contributing to Qdrant Skills

Skills encode solutions architect knowledge for AI agents. Familiarity with [Qdrant documentation](https://qdrant.tech/documentation/) and the [Agent Skills standard](https://agentskills.io/) is recommended before contributing.


## Philosophy

Skills are not a different form of documentation or tutorials.

Documentation answers "how?" Skills answer "when?" and "why?"

Skills serve as agentic-friendly navigation to Qdrant documentation, not a
replacement for it. They encode the judgment of a Solutions Architect: given a
symptom, which part of the docs matters, what order to try things, and what to
avoid. If the guidance could be written by reading a getting-started page for
10 minutes, it's not a skill. Skills encode judgment that comes from operating
Qdrant at scale.

### Good skill

```
## What to do if memory usage is too high?
- Check collection parameters [link to docs]
- Apply quantization [link to choosing quantization]
- Monitor memory usage in prod [link to grafana dashboard]
```

### Bad skill

```
## Multimodal RAG: Building Document Search
- Build a RAG system using embeddings and Ollama for generation
- Implement basic retrieval from a collection
```

```
## Integrating Qdrant with Framework X
- Install the framework package
- Configure the vector store
- Run a similarity search
```

The first is a tutorial. The second is an integration guide. Neither is a
skill, because neither requires operational judgment to write.

Skills should not create maintenance obligations across external frameworks
or SDKs. Reference the docs, don't replicate them.


## Structure

```
skills/
  <skill-name>/
    SKILL.md              # skill definition (frontmatter + guidance)
    <sub-skill>/
      SKILL.md            # sub-skill for a specific topic
```

**Skills** (`skills/`): passive knowledge triggered by description matching. Diagnosis and guidance. Read-only tools.


## Writing a skill

### Hub skills (navigation only)

Hub skills are directories containing sub-skills. They provide a framing paragraph and links to sub-skills.

- Declare `allowed-tools: [Read, Grep, Glob]` in frontmatter
- Include `name` and `description` with trigger phrases
- Body is navigation only: title, framing paragraph, links

### Leaf skills (actual content)

Leaf skills contain the guidance an agent uses to help users.

- Omit `allowed-tools` from frontmatter (exception: skills that need `Bash` for external API calls)
- Description contains `Use when` with 5+ trigger phrases using exact user language
- First paragraph corrects a wrong assumption or forces a diagnostic fork
- Sections named by symptom/scenario, not by feature
- Each section starts with `Use when:` one-liner
- Bullets are imperative with inline doc links at the end
- Ends with `## What NOT to Do` section
- No code blocks in skills beyond absolutely minimal snippets (reference the docs instead)
- Links go to `search.qdrant.tech/md/documentation/`, not raw GitHub
- Target 40-80 lines; if over 80, consider splitting into hub + sub-skills


## Conventions

### Commit messages

- Lowercase, imperative, no period at end
- Short and direct: `"fix broken links"`, `"add sliding time window skill"`
- Multi-step changes use `*` bullet points in body

### PR titles

- Lowercase, technical, under 70 chars
- Action or problem focused: `"fix X"`, `"add docs for Y"`, `"refactor Z"`

### PRs

- Small, focused: one logical change per PR
- 1-2 sentence summary of what the PR does
- Link related PRs/issues
