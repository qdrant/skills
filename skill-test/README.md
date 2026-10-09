# Claude Code Skill Test Harness

This repo runs an agent CLI — Claude Code or Codex — inside a fresh Docker
container for each prompt, captures the answer, and avoids reusing local
agent state between tests. Claude Code is the default; pass `--agent codex`
to any `run-claude-test.sh` command to use Codex instead (see "Choose An
Agent" below). Everything in this README defaults to Claude Code unless a
section says otherwise — the periodic scoring pipeline (`scripts/scoring/`,
`SCORING.md`) in particular is Claude-only for now.

## Why This Is Fresh

Each run starts a new container with a new container-local `HOME`. The host
`~/.claude` directory is not mounted. The container command also uses
`claude -p --no-session-persistence`, so Claude Code does not save a resumable
session for the prompt.

## Build

```bash
scripts/build-image.sh
```

The base image and package install come from the network, so transient Docker
Hub or npm timeouts can happen. The build script retries three times by default:

```bash
scripts/build-image.sh --attempts 5
```

If you already have a different Node image locally, or Docker Hub is struggling
with that exact tag, use another Debian-based Node image:

```bash
scripts/build-image.sh --node-image node:22-bookworm
```

To pin Claude Code:

```bash
scripts/build-image.sh --claude-code-version 2.1.89
```

The image bundles both agent CLIs, so one build covers `--agent claude` and
`--agent codex`. Codex is pinned by default (`--codex-version 0.160.1`) rather
than floating on `latest` — its flags were observed to change between patch
releases during development:

```bash
scripts/build-image.sh --codex-version 0.160.1
```

## Auth

**Claude Code** (default): generate a Claude Platform API key at
https://platform.claude.com/, then add it to your local `.env` file:

```bash
cp .env.example .env
```

Then edit `.env` and set `ANTHROPIC_API_KEY`.

You can also skip `.env` and export credentials in your shell before running the
script.

If a run exits with `Not logged in · Please run /login`, the fresh container did
not receive usable credentials. Check that `.env` contains a non-empty
`ANTHROPIC_API_KEY`, or pass `--env-file /path/to/env`.

**Codex** (`--agent codex`): generate an API key at https://platform.openai.com/,
then set `OPENAI_API_KEY` (or `CODEX_API_KEY`) in `.env` the same way. Codex's
`exec` doesn't read the key directly — the container runs `codex login
--with-api-key` from it before the actual test, which is why a Codex auth
failure shows up as a `401 Unauthorized` in `stdout.txt` rather than the
`Not logged in` message Claude Code prints.

## Run A Smoke Test

```bash
scripts/run-claude-test.sh prompts/qdrant-smoke.md
```

Or build and run in one step:

```bash
scripts/run-claude-test.sh --build prompts/qdrant-smoke.md
```

Each run writes:

```text
runs/<run-id>/
  metadata.json
  prompt.md
  readable.md   (--agent claude only — see below)
  stderr.txt
  stdout.txt
  final.txt     (--agent codex only — the clean final answer)
```

`metadata.json` always carries an `agent` field (`"claude"` or `"codex"`).

`readable.md` is generated automatically after each `--agent claude` run. To
regenerate it, or to turn an older Claude Code `stream-json` output into a
readable transcript:

```bash
scripts/render-claude-stdout.js runs/<run-id>
```

With no argument, it renders the newest run under `runs/`:

```bash
scripts/render-claude-stdout.js
```

To save the transcript:

```bash
scripts/render-claude-stdout.js runs/<run-id> --output runs/<run-id>/readable.md
```

This renderer only understands Claude Code's `stream-json` shape. `--agent
codex` runs are not rendered yet — read `stdout.txt` (Codex's own `--json`
event stream) or `final.txt` (just the final answer) directly.

## Choose An Agent

```bash
scripts/run-claude-test.sh --agent codex --model gpt-6-sol prompts/qdrant-smoke.md
```

`--agent` defaults to `claude`, so every example elsewhere in this README that
doesn't pass `--agent` runs Claude Code exactly as before. Switching to `codex`
changes a few things:

- **Models** are a disjoint namespace from Claude's (`gpt-6-sol`, not
  `sonnet`/`haiku`/`opus`) and have been observed to churn between CLI
  releases — pass `--model` explicitly if `--choose-model`'s menu looks stale.
- **`--skills-dir`** works the same way for both agents (a directory with
  `SKILL.md`, or several such subdirectories); Codex discovers skills at
  `.codex/skills/<name>/SKILL.md` under the workspace rather than Claude's
  `~/.claude/skills/<name>/`, but the harness handles that difference for you.
- **`--plugin-dir`/`--plugin-url`** are Claude-only and are ignored (with a
  warning) under `--agent codex`.
- **`--max-turns`/`--max-budget-usd`** are Claude-only too — Codex's `exec`
  has no turn-cap or budget-cap flag, so these are ignored (with a warning)
  rather than silently doing nothing.
- **`--permission-mode`** still takes the same six values; see "Permission
  Modes" below for how they map onto Codex's own sandbox/approval flags.

## Run A JSON Test-Prompt

The prompt file may also be a JSON test-prompt (for example the files under
`skills/evals/test-prompts/`) that carries the prompt plus scoring metadata:

```json
{
  "name": "qdrant-hybrid-search",
  "product_area": "hybrid search",
  "skill_url": "https://skills.qdrant.tech/.../SKILL.md",
  "prompt": "We run hybrid search (dense + sparse) inside one large collection ...",
  "rubric": [ { "type": "must", "text": "..." } ]
}
```

Pass the `.json` file directly:

```bash
scripts/run-claude-test.sh ../skills/evals/test-prompts/qdrant-hybrid-search.json
```

The runner validates that the file parses and has a non-empty string `prompt`
field, extracts that field, and sends only it to Claude Code. The run id is
derived from the test-prompt's `name` field (falling back to the file name if
`name` is missing), and the original JSON is copied to
`runs/<run-id>/test-prompt.json` so its `rubric`, `skill_url`, and
`product_area` are available for scoring alongside the transcript.

Reading a JSON test-prompt requires `jq` on the host (it extracts the `prompt`
field before the container starts). On macOS, install it with `brew install jq`.
The runner exits with a clear error if `jq` is missing.

## Run A Batch Of Test-Prompts

To run several test-prompts in one go, use the batch wrapper. Each argument is
either a file or a directory (every `*.json` inside it is run, sorted by name):

```bash
scripts/run-claude-test-batch.sh ../skills/evals/test-prompts
```

Options placed before a literal `--` are forwarded verbatim to every underlying
`run-claude-test.sh` invocation:

```bash
scripts/run-claude-test-batch.sh --model sonnet --max-turns 20 -- \
  ../skills/evals/test-prompts/qdrant-hybrid-search.json \
  ../skills/evals/test-prompts/qdrant-tenant-scaling.json
```

Build the image once first (`scripts/build-image.sh`) rather than passing
`--build`, which would rebuild before every run. The batch continues past a
failing run, prints a pass/fail summary, and exits non-zero if any run failed.

## Test Local Skills

If you have a local skill directory containing `SKILL.md`:

```bash
scripts/run-claude-test.sh \
  --skills-dir ./skills/qdrant \
  prompts/qdrant-smoke.md
```

If you have a directory containing multiple skills, each child directory with a
`SKILL.md` is installed into the fresh container for that run.

## Test Plugin URLs

Claude Code only (Codex has no plugin-zip equivalent). If `skills.qdrant.tech`
provides a Claude Code plugin zip URL, pass it directly:

```bash
scripts/run-claude-test.sh \
  --plugin-url https://skills.qdrant.tech/path/to/plugin.zip \
  prompts/qdrant-smoke.md
```

Repeat `--plugin-url` for multiple plugin zips.

## Test Remote Skill Discovery

To test a prompt where the skill is not installed locally and Claude must reach
the remote URL itself:

```bash
scripts/run-claude-test.sh \
  --permission-mode bypassPermissions \
  --max-turns 20 \
  prompts/qdrant-latency-remote-skill.md
```

This prompt contains:

```text
My search latency jumped from 80ms to 400ms p99 over the weekend. How do I figure out what changed? Use skills.qdrant.tech
```

Use `bypassPermissions` only in the disposable Docker container. It lets Claude
Code run commands such as `curl` to inspect `skills.qdrant.tech`; without that,
a non-interactive run may be unable to fetch the remote skill source and may
answer from general knowledge instead.

For an auditable transcript that can show whether Claude actually used a tool to
inspect the URL, add verbose output:

```bash
scripts/run-claude-test.sh \
  --permission-mode bypassPermissions \
  --max-turns 20 \
  --extra-args "--verbose" \
  prompts/qdrant-latency-remote-skill.md
```

## Interrogate Further

Claude-only for now — there's no Codex equivalent of `run-claude-session.sh` yet.
For an interactive same-instance investigation, start a disposable session:

```bash
scripts/run-claude-session.sh \
  --skills-dir ./skills/qdrant \
  prompts/qdrant-smoke.md
```

You can ask follow-up questions inside Claude Code. When you exit, the container
is removed, so the session does not leak into the next test.

For stricter auditability, create a second prompt and run it as a new test. To
preserve visible context, include the previous `stdout.txt` content in your
follow-up prompt file and run another fresh container.

## Permission Modes

Pass `--permission-mode MODE` to `run-claude-test.sh` or `run-claude-session.sh`
to set, for that single test run, which actions Claude Code may take without
stopping to ask you for approval. The runner validates the value and rejects
anything outside this list:

- `default` — Claude asks before each file edit, shell command, or network request; only reads run without a prompt. Shown as "Manual" in the CLI, and `manual` is an accepted alias.
- `acceptEdits` — Auto-approves file edits and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`, etc.) inside the working directory; everything else still prompts.
- `plan` — Claude researches and proposes changes without editing anything; edits stay blocked until you approve a plan.
- `auto` — Runs without routine prompts while a background classifier blocks risky actions; requires a supported plan and model.
- `dontAsk` — Auto-denies anything not pre-approved, running only allow-listed tools and read-only commands, and never waits for input; best for unattended runs. In a non-interactive container there is no one to answer a permission prompt, so instead of stalling, `dontAsk` denies the call, hands the denial back to Claude, and lets the run continue to completion.
- `bypassPermissions` — Skips all permission checks so every tool call runs immediately. Use only inside an isolated container or VM.

Mode names are **case-sensitive**: pass them exactly as written above, for
example `dontAsk` (not `dontask` or `DontAsk`). The runner rejects any other
spelling.

For the full reference, see the Claude Code docs:
<https://code.claude.com/docs/en/permission-modes>.

### With `--agent codex`

Codex has no single `--permission-mode` flag — it has two independent ones
instead, `--sandbox {read-only,workspace-write,danger-full-access}` and
`--approve-for-me`/the full-bypass flag. The container maps the same six mode
names onto them:

| `--permission-mode` | Codex flags | Why |
|---|---|---|
| `bypassPermissions`, `dontAsk` | `--dangerously-bypass-approvals-and-sandbox` | Codex's `exec` has no interactive approval prompt or tool allow-list to fall back to non-interactively, so both modes collapse to a full bypass — the outer disposable container is the real isolation boundary either way. |
| `auto`, `acceptEdits` | `--approve-for-me` | `workspace-write` sandbox with Codex auto-reviewing its own actions. |
| `plan`, `default`, `manual` | `--sandbox read-only` | No one is present to approve an edit or a command, so the most faithful analog of "asks before acting" is "can't write at all." |

The chosen mode is recorded in `metadata.json`'s `permission_mode` field either way.

## Useful Options

Flags may appear in any order relative to the prompt file, so
`run-claude-test.sh prompts/x.md --permission-mode plan` and
`run-claude-test.sh --permission-mode plan prompts/x.md` are equivalent. An
unexpected second positional argument is rejected rather than silently ignored.

```bash
scripts/run-claude-test.sh \
  --model sonnet \
  --max-turns 20 \
  --max-budget-usd 1.00 \
  --permission-mode auto \
  prompts/qdrant-smoke.md
```

`auto` is the default permission mode here. Rather than hard-denying anything not
pre-approved the way `dontAsk` does, it lets Claude work through in-scope actions
without asking permission from the user while a background classifier still blocks
anything beyond the task's scope — a better fit for unattended runs that should get
real work done. For a stricter, fully locked-down run, pass
`--permission-mode dontAsk`, which only ever runs pre-approved tools.

Note one edge case for headless (`-p`) runs like these: in `auto` mode the run
**aborts** if the classifier blocks the same action 3 times in a row or 20 times
total, since there is no user to approve a fallback prompt. A test that repeatedly
attempts out-of-scope actions can therefore end early, where `dontAsk` would
deny each call and let the run continue to completion.

By default the run id (the `runs/<id>/` directory name and the Docker container
`--name`) is derived from the timestamp and the prompt name. Pass `--run-id ID`
to set it explicitly instead:

```bash
scripts/run-claude-test.sh --run-id my-unique-id prompts/qdrant-smoke.md
```

`ID` must start with a letter or digit, then letters, digits, `.`, `_`, `-`
(Docker's `--name` rule). This lets a batch runner give each run a unique,
descriptive id so that **concurrent** runs never collide on a directory or a
Docker `--name` (two runs of the same prompt in the same second would otherwise
clash).

For tests that intentionally need Claude Code to execute commands or edit a
throwaway workspace, use a disposable workspace and pass a more permissive mode,
for example:

```bash
scripts/run-claude-test.sh \
  --workspace ./fixtures/example-project \
  --workspace-rw \
  --permission-mode bypassPermissions \
  prompts/my-agentic-test.md
```

## Choose Model Interactively

Instead of specifying a model name directly, use `--choose-model` to select from
a menu:

```bash
scripts/run-claude-test.sh --choose-model prompts/qdrant-smoke.md
```

This will prompt you:

```text
Select a Claude model:
1) haiku
2) sonnet
3) opus
#?
```

Type `1`, `2`, or `3` and press Enter. The test will run with your chosen model.
The selected model is recorded in the run's `metadata.json` for reference.

With `--agent codex`, the same flag offers a short Codex model menu instead
(`gpt-6-sol`, `gpt-6-astra`, `gpt-6-luna` as of this writing). Codex model
names have been observed to change between CLI releases faster than this
menu is likely to be updated — pass `--model` explicitly if the options look
wrong, or if `codex -h` lists something this menu doesn't.

## A/B Test Two Skill Versions

Claude-only for now — `scripts/scoring/` doesn't know about `--agent` yet.

`scripts/scoring/` carries the same periodic (monthly) scoring harness described in
[`SCORING.md`](SCORING.md) (`run-eval-matrix.sh` → `extract-run-signals.sh` →
`judge-runs.sh`). That pipeline measures **lift** — a skill installed vs not —
by diffing the `no-skill` and `with-skill` conditions inside one run.

`scripts/scoring/compare-ab.py` answers a different question: **which of two
versions of the same skill is better** — e.g. the current skill on `main`
against a candidate change on a PR branch. It diffs two separate run
directories that each used the `with-skill` condition, one per skill version,
scored against the same prompts.

### 1. Run each version through the normal pipeline

Point `--skills-root` at a checkout of each version and score only the
prompt(s) that exercise the skill under test (via `--prompts-dir`, pointed at
a directory containing just those `*.json` files — copy the relevant ones out
of `evals/test-prompts/` or `../skills/evals/test-prompts/` for this):

```bash
# Version A — e.g. the skill as it stands on main
scripts/scoring/run-eval-matrix.sh \
  --conditions with-skill \
  --skills-root /path/to/main-checkout/skills \
  --prompts-dir ./ab-prompts \
  --out-dir evals/ab/version-a
scripts/scoring/extract-run-signals.sh --out-dir evals/ab/version-a
scripts/scoring/judge-runs.sh --out-dir evals/ab/version-a

# Version B — e.g. the skill as amended by a PR branch
scripts/scoring/run-eval-matrix.sh \
  --conditions with-skill \
  --skills-root /path/to/pr-checkout/skills \
  --prompts-dir ./ab-prompts \
  --out-dir evals/ab/version-b
scripts/scoring/extract-run-signals.sh --out-dir evals/ab/version-b
scripts/scoring/judge-runs.sh --out-dir evals/ab/version-b
```

`--models`, `--reps`, `--max-turns`, and `--max-budget-usd` all default the
same way as a periodic run (see `run-eval-matrix.sh --help`); scope them down
for a cheap local check, e.g. `--models sonnet --reps 2`.

### 2. Compare

```bash
scripts/scoring/compare-ab.py \
  --a evals/ab/version-a \
  --b evals/ab/version-b \
  --label-a main \
  --label-b pr-123
```

This writes `ab-scorecard.md` next to the `--b` directory (override with
`--out`) and prints it to stdout: a per-model `must_coverage` delta (B − A)
with a paired standard error and a 95%-CI-excludes-zero flag, a per-prompt
breakdown, `avoid`-violation detail for each version, and a coverage section
listing any dropped runs — the same shape as the periodic `scorecard.md`, just
diffing two named versions instead of two conditions. Nothing here gates; it's
a report to read before deciding whether to merge.
