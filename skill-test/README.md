# Claude Code Skill Test Harness

This skill test framework runs Claude Code inside a fresh Docker container for each prompt, captures
the answer, and avoids reusing local Claude state between tests.

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

## Auth

Use an API key for scripted runs:

Generate a Claude Platform API key at https://platform.claude.com/. Next, add this key to your local `.env` file:

```bash
cp .env.example .env
```

Then edit `.env` and set `ANTHROPIC_API_KEY`.

You can also skip `.env` and export credentials in your shell before running the
script.

If a run exits with `Not logged in · Please run /login`, the fresh container did
not receive usable credentials. Check that `.env` contains a non-empty
`ANTHROPIC_API_KEY`, or pass `--env-file /path/to/env`.

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
  readable.md
  stderr.txt
  stdout.txt
```

`readable.md` is generated automatically after each run. To regenerate it, or to
turn an older Claude Code `stream-json` output into a readable transcript:

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

## Run A JSON Test-Prompt

The prompt file may also be a JSON test-prompt (for example the files under
`evals/test-prompts/`) that carries the prompt plus scoring metadata:

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
scripts/run-claude-test.sh ../evals/test-prompts/qdrant-hybrid-search.json
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
scripts/run-claude-test-batch.sh ../evals/test-prompts
```

Options placed before a literal `--` are forwarded verbatim to every underlying
`run-claude-test.sh` invocation:

```bash
scripts/run-claude-test-batch.sh --model sonnet --max-turns 20 -- \
  ../evals/test-prompts/qdrant-hybrid-search.json \
  ../evals/test-prompts/qdrant-tenant-scaling.json
```

Build the image once first (`scripts/build-image.sh`) rather than passing
`--build`, which would rebuild before every run. The batch continues past a
failing run, prints a pass/fail summary, and exits non-zero if any run failed.

## Test Local Skills

If you have a local skill directory containing `SKILL.md`:

```bash
scripts/run-claude-test.sh \
  --skills-dir ../skills/qdrant-scaling \
  prompts/qdrant-smoke.md
```

If you have a directory containing multiple skills, each child directory with a
`SKILL.md` is installed into the fresh container for that run.

## Test Plugin URLs

If `skills.qdrant.tech` provides a Claude Code plugin zip URL, pass it directly:

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

For an interactive same-instance investigation, start a disposable session:

```bash
scripts/run-claude-session.sh \
  --skills-dir ../skills/qdrant-scaling \
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
