# Weekly Skill Scoring

This describes how the harness turns test prompts into a weekly score that tells
us whether a skill actually helps a model, and by how much.

## What We Measure

We do not care about a model's absolute score. We care about **skill lift**: how
much better a model answers *with* the skill installed than *without* it.

```text
lift(model) = mean_score(model, with-skill) − mean_score(model, no-skill)
```

A skill that earns its keep produces positive lift. Lift is reported **per
model**, because a good skill typically lifts a smaller model (Haiku) far more
than a larger one (Sonnet) that already knows much of the material from
pretraining. A skill with near-zero lift on both models is a candidate for
rewriting or retirement.

Both arms have web search, so lift is measured against a baseline that can reach
`docs.qdrant.tech` and `skills.qdrant.tech`, not against a bare model. That is
the honest counterfactual for a real user, and it sets a harder bar: expect
smaller lift numbers than a no-web baseline would produce.

Low lift therefore has two readings, and they are worth separating before anyone rewrites a skill.
Either the skill is weak, or the public docs already cover that ground well, in which case merging or retiring the skill is the right call rather than expanding it.

## The Evaluation Matrix

Every prompt is run across a 2×2 matrix, `k` times per cell:

|              | no skill | with skill |
|--------------|----------|------------|
| **Sonnet**   | baseline | treatment  |
| **Haiku**    | baseline | treatment  |

- **Prompts:** every `*.json` under `evals/test-prompts/` **except** those with
  the `discord-` prefix (26 prompts at time of writing).
- **`k` (repetitions):** default **2**. Model output is stochastic; one run per
  cell is too noisy to trust a rubric item that can flip on rerun. Two reps is a
  deliberate cost-first setting: it still exposes an unstable item (the two reps
  disagree) and a min–max spread, but gives no generation-level majority vote and
  only a weak variance estimate. It's planned to raise it once the pipeline is
  trusted and the first weeks of data justify the extra spend. Scores are averaged
  over the `k` reps and we also report spread.
- **Volume:** `26 prompts × 2 models × 2 conditions × 2 reps = 208` runs/week.

The `with skill` arm **explicitly installs** the skill into the container — its
`SKILL.md` and files are placed under `~/.claude/skills/<name>/` before the run,
so Claude Code registers it at startup. The `no skill` arm runs the same prompt
in the same fresh container with nothing installed.

Two things about the skill are recorded per run:

- **Availability** (a hard check). The installed skill must appear in the run's
  `init` skill list. Because install is explicit rather than best-effort, an
  absent skill is a real harness failure — a broken install path or image drift,
  not a model choice — so such a run is **invalid**, excluded from scoring, and
  reported. This is a cheap tripwire, not a likely event.
- **Activation** (recorded, never gated). *How* the model reached the skill:
  `skill_tool` (invoked via progressive disclosure), `file_read` (read the
  installed `SKILL.md` directly), `web_fetch` (pulled the published copy from
  `skills.qdrant.tech` instead), or `none`. Because install is guaranteed, a
  `none` is unambiguous: the skill was present and the model did not reach for it.
  That is a **trigger miss** — a real signal about the skill's description, not a
  harness bug — so the run stays in scoring and the miss is flagged. Persistent
  `none` on a skill is a triggering problem to fix in that skill, not a run to
  throw away. Recording the source also matters because `web_fetch` means the
  run's lift came from the published copy, not the local `SKILL.md` under test.

### Tool Parity Across Arms

Both arms get an **identical toolset with web search enabled**, and nothing is
blocked. Any asymmetry here contaminates lift: a baseline without web access
inflates it, and a baseline with tools the treatment lacks deflates it. Blocking
a domain would create a third kind of asymmetry, between the harness and the
user, and a score measured under conditions no user runs in is not the score we
want to track.

This interacts with the `dontAsk` mode scored runs use (see Weekly Run). On its
own `dontAsk` denies exactly the tools scoring depends on — the `Skill` tool and
web search/fetch — which would silently defeat both skill activation and the
web-enabled baseline. So both arms are run under `dontAsk` **with an identical
allow-list**, `Skill,WebSearch,WebFetch,Read,Grep,Glob,Bash`, applied the same
way to no-skill and with-skill. That is how "identical toolset, web enabled,
nothing relevant blocked" is delivered while still keeping `dontAsk`'s guarantee
that a run cannot wander into edits or other out-of-scope actions. The allow-list
is a measurement parameter: changing it changes what lift means, so it is pinned
alongside the CLI version and model snapshots. (A denied tool call still surfaces
in a run's `permission_denials`; the extractor nets those out so a denied attempt
never counts as activation or a fetch.)

Leaving `skills.qdrant.tech` reachable has consequences worth stating plainly,
because they change what lift means:

- The `with-skill` arm may read the published copy of a skill as well as the
  local files under test. A scored run is therefore not a clean measurement of
  the local `SKILL.md` alone. Keep the local files and the published site in sync,
  and record the skills commit in the manifest, so that when the two disagree you
  can see it rather than infer it.
- The `no-skill` arm can also find `skills.qdrant.tech` and effectively serve
  itself the skill. That is exactly what a user could do, so it belongs in the
  baseline, but it means lift measures "skill installed" against "skill
  discoverable on the open web". That is a harder bar than a bare model, and
  near-zero lift on a prompt may mean the skill is easy to find rather than
  unhelpful.
- Fetched URLs are recorded per run, and this is what makes the previous point
  tractable. Segment baseline runs by whether they reached `skills.qdrant.tech`:
  if the same prompt hits it in one rep and not the next, that alone moves the
  score, and the URL log is how you attribute the variance instead of chasing it.
  `docs.qdrant.tech` is an input to both arms for the same reason, so a docs
  change can move scores with no skill change.

### Prompt Sets

The `discord-` prefixed prompts are **reserved, not excluded**. They are real
user messages, and they are the only prompts we have that nobody wrote with a
skill in front of them.

Their first role is as a held-out set for measuring generalization: once we start
editing skills in response to eval failures, the scored prompts stop being able
to tell real improvement from tuning to the test, and an unoptimized set is the
only way to recover that signal. They have other likely uses too, including
paraphrase robustness checks, trigger precision tests, and a source of
replacements as scored prompts saturate.

None of that works if they get folded into the scored set first. The point at which we need them is the first skill edit motivated by an eval result, not the first run.

## Rubric Format

Each prompt file carries a `prompt` and a `rubric` array. Every rubric item has
a `type` and a `text`:

```json
{
  "prompt": "...user question...",
  "rubric": [
    { "type": "must",  "text": "Recommends RRF as the default because score scales are incomparable" },
    { "type": "bonus", "text": "Mentions custom fusion via a formula query" },
    { "type": "avoid", "text": "Picks a fusion method without running comparative experiments" }
  ]
}
```

- **`must`** — the answer is expected to contain this. Missing musts are the
  primary quality failure. (Three to five per prompt.)
- **`bonus`** — a nice-to-have that shows depth. Never required. (One to three
  per prompt.)
- **`avoid`** — the answer must *not* do this. A violation is an active harm (a
  hallucinated config key, or recommending an expensive approach without the
  cheap alternative), not a mere omission. (One to three per prompt.)

## Grading: The Judge

Grading is done by an **LLM judge (Opus)**, one verdict per rubric item.

The judge runs under three rules:

1. **Blind.** The judge sees only the prompt, the final answer, and the rubric.
   It does **not** see the model name or whether the skill was installed,
   otherwise it anchors. That metadata is stripped before grading and order is shuffled.
2. **Final answer only.** The judge grades only the last assistant message, not the full
   transcript. Thinking and tool-call noise are not the deliverable. The
   transcript is still captured, because the availability check, the activation
   signal, and the URL log are derived from it.
3. **Evidence required.** For every "met" or "violated" verdict the judge must
   quote the supporting span from the answer. Requiring a quote sharply reduces
   hallucinated "yes, it covered that" grades.

Two reliability additions for the items that matter most:

- **`must` items:** verdicts are **binary**, `met` or `missing`, with no partial
  credit. Partial is where judge leniency drifts, and it makes week-over-week
  diffs unreadable.
- **`avoid` items:** adversarial framing. The judge actively hunts for the violation
  and marks `clean` only if it genuinely cannot find one. Misses here are expensive.

**Scoring runs a single judge sample per item.** The cell score aggregates
roughly 200 items across two generation reps, so a single judge's per-item jitter
is already heavily diluted in the headline lift number; multi-sample voting mostly
buys per-item stability and a rubric-ambiguity signal, not a better aggregate, and
musts are the largest judging cost.

That single-sample choice is backed by a **self-agreement** calibration we ran,
not just assumed. The protocol: grade the same answer three times and count how
often a single verdict flips.

We ran it on 2026-07-30 against the first available scored transcript —
`qdrant-minimize-latency`, no-skill arm (3 must / 2 bonus / 2 avoid) —
graded three times by the Opus judge against quoted evidence. All 7 items came
back unanimous across the three samples, including 3/3 binary musts,
clearing the ≥95%-on-musts bar. On that basis one vote stands. This is an initial
result on a single transcript; we re-run the same calibration across a handful of
transcripts once the weekly matrix has produced them, and escalate if it turns up
noise — preferably to two samples with a third only to break a disagreement (≈2×
cost, not 3×), which resolves to a majority and yields the `contested` flag for
free. An item whose two samples disagree is flagged `contested` in `scores.csv`;
items that come back contested week after week are worded ambiguously rather than
hard, and that flag is the rubric-quality backlog. We revisit the vote count once
four weeks of data exist, alongside the threshold decisions.

### Per-Item Credit

| type    | verdicts → credit                                  |
|---------|----------------------------------------------------|
| `must`  | met `1.0` · missing `0.0`                           |
| `bonus` | met `1.0` · absent `0.0`                            |
| `avoid` | violated `1.0` · clean `0.0` (a violation *count*)  |

Note the inverted polarity: for `avoid`, `1.0` is bad. `scores.csv` therefore
carries both the raw `credit` and a signed `contribution` column, so that summing
across item types cannot silently produce nonsense.

## Scoring Math

We report **three separate per-prompt metrics** rather than collapsing early,
because they answer different questions and averaging them hides the important
one:

```text
must_coverage    = Σ must_credit  / n_must       ∈ [0,1]   # correctness / completeness (primary)
bonus_rate       = Σ bonus_credit / n_bonus      ∈ [0,1]   # depth
avoid_violations = Σ avoid_violated              (count)   # safety / harm
```

For ranking and dashboards we also compute a single **composite**, with musts
dominant, bonus as a small bump that can never rescue missing musts, and avoid as
a real penalty:

```text
composite = clamp( must_coverage
                   + 0.10 * bonus_rate
                   − 0.25 * avoid_violations,
                   0, 1 )
```

The composite is for trend lines and ranking only. Because it clamps at zero, it
stops distinguishing bad answers from worse ones past three violations, which is
one reason `avoid_violations` is also reported raw and checked separately.

### Aggregation

There is exactly one prompt per skill, so a prompt and a skill are the same unit
of measurement here. We aggregate in three levels, averaging at each one rather than
pooling all items:

```text
item        → 0/1 from the judge
prompt×rep  → the three metrics, plus composite
prompt      → mean over its k reps (report min–max as a stability signal)
cell        → mean over all prompts                 (flat, macro)
```

The cell score is a **flat per-prompt macro-average**: every prompt (and so every
skill) counts exactly once, no matter how long its rubric is.

Averaging prompts rather than pooling their items keeps rubric length out of the
score. Pooling makes a prompt with eight musts count nearly three times a prompt
with three, which reflects how much someone wrote, not how much the prompt
matters.

Flat per-prompt weighting is what gives every skill an equal say. Because each
skill has one prompt, one prompt regressing moves the headline by the same amount
regardless of which skill it belongs to, so no skill can dominate or hide. That is
the question the scorecard answers: "is every skill healthy".

### Reading Week-Over-Week Movement

The `k` reps only capture generation variance — they say nothing about the fact
that 26 prompts are a small sample of all possible Qdrant questions, and rubric
items cluster (a skill that fails to trigger loses all its musts at once). So a
cell score is noisier than its item count suggests.

Two quantities on the scorecard turn that caution into a rule, and they measure
different noise:

- **Within-week SE** (shown every week from week one as `lift ± SE`, with a
  `95% CI ≠ 0?` flag). This is the paired per-prompt standard error,
  `stdev(dᵢ)/√n` over the scored prompts, where `dᵢ` is a prompt's
  (`with_skill_value`-`no_skill_value`) lift. It answers the single-week question:
  is a skill's lift distinguishable from zero at all, or is it just which questions
  we happened to ask? A `no` flag means don't act on that lift yet. It captures
  sampling noise only, not drift.
- **Between-week σ** (the empirical spread of prior weeks' lift). This captures
  what the within-week SE cannot measure: drift in the model build, docs, or judge
  between runs. It needs prior weeks to exist, so the week-over-week delta reads
  `Will be computed after four runs.` until then.

The practical rule combines them: **don't act on a week-over-week movement smaller
than `max(t·SE_Δ, between-week σ)`** — a real move must clear both this week's
sampling error (`SE_Δ = √(SE_now² + SE_prev²)`) and the observed drift. Until four
weeks of data exist, lean on the within-week SE and treat small deltas as noise by
default, investigating only large or sustained moves — a sustained trend is not the
same as random bounce, and the threshold is built for the latter.

## Thresholds And Gating

The framework is deliberately **ungated for now**, with one exception. Setting
thresholds before we know the distribution produces either an ungrounded gate or
constant false alarms, so the first weeks are for observation.

One thing is a hard check from week one, because it needs no baseline data to
interpret:

- The availability check on every `with-skill` run: the installed skill must
  appear in the run's `init` skill list, or the run is invalid and excluded.
  Activation (`skill_tool`/`file_read`/`web_fetch`/`none`) is recorded but never
  gated — a `none` is a trigger miss to surface, not a failure to exclude.

`avoid` violations, including fabricated identifiers, are **penalized but not
gated**. A fabrication is the most damaging thing an answer can do, so gating on
it is tempting, but we have no trustworthy way to detect it yet: unlike a rubric
item, the judge is not handed the text to check against and would have to know
what is real in Qdrant, so a fabrication gate would fail good runs on false flags.
A gate we cannot trust is worse than none, so fabrications ride the graded `−0.25`
avoid penalty until a reliable detector exists. Revisit this when one does.

Revisit after four weeks and set thresholds on `must_coverage` and lift from the
variance we actually observe. Until then the scorecard is a report, so record that
deferral here with its date rather than leaving the absence of gates implicit.

## Weekly Run

```bash
# 0. Preflight: confirm every prompt's skill_url resolves to a real skill on disk.
scripts/scoring/validate-prompts.sh

# 1. Generate: run the full 2×2×k matrix over the scored (non-discord) prompts.
#    Writes runs + a base manifest to evals/weekly/<UTC-date>/.
scripts/scoring/run-eval-matrix.sh --models sonnet,haiku --reps 2

# 2. Extract signals: enrich the manifest (availability, activation, cost, budget).
scripts/scoring/extract-run-signals.sh --out-dir evals/weekly/<date>

# 3. Judge: grade every valid run's final answer against its rubric (Opus, blind).
#    Resumable: re-running skips runs already in scores.csv, so an interrupted
#    judge pass continues without re-grading (or re-paying for) completed runs.
#    Pass --fresh to discard scores.csv and grade every run from scratch.
scripts/scoring/judge-runs.sh --out-dir evals/weekly/<date>

# 4. Summarize: aggregate to the per-model lift + efficiency scorecard.
scripts/scoring/summarize-eval.py evals/weekly/<date>
```

Scored runs use `--permission-mode dontAsk` (the run cannot wander off-task; any
out-of-scope tool call is denied and the run continues) rather than
`bypassPermissions`, together with a shared tool allow-list
(`Skill,WebSearch,WebFetch,Read,Grep,Glob,Bash`) so the tools scoring needs are
available in both arms — refer to Tool Parity Across Arms for why this pairing is
required, not optional.

Each run also carries a per-run spend cap (`--max-budget-usd`, default **$2**), a
runaway backstop set well above the normal per-run cost (cents), not a routine
limiter. A run that hits it stops truncated; it is marked `budget_hit`, excluded
from scoring and the cost mean, and reported as budget-capped — because a
truncated answer would grade unfairly low and its cost is a floor, not the real
figure. Keep the cap high enough that legitimate runs never hit it; if several do,
raise it rather than let clipped runs contaminate the numbers.

The runs are independent, so `run-eval-matrix.sh --jobs N` executes N at a time
(default 1). Each run is its own fresh container with a unique per-invocation id,
so at the recommended **2–3** concurrency this changes **wall-time only — not
results or cost** (same runs, same tokens). Runs are API-latency-bound, so 2–3
roughly halves/thirds the generation phase at negligible local cost. Do not push
it higher: at ≥4 you risk API rate limits, and a rate-limited run *can* change
results — so the wall-time-only guarantee holds only in the 2–3 range. The judge
stage is unaffected.

Confirm the skill-install step and `--permission-mode dontAsk` work on the pinned
CLI version before the first scored run — verify an installed skill actually shows
up in the `init` skill list, **and that the allow-listed tools are not denied**
(check a run's `permission_denials` is empty for `Skill`/`WebFetch`/`WebSearch`) —
and pin that version, the allow-list, the model snapshot strings, and the skills
commit in the manifest. An install that silently no-ops, or a flag the CLI ignores,
fails as zero lift rather than as an error.

## Outputs

For a plain-language glossary of every number in `scorecard.md` and `scores.csv`
— what each field means, in a sentence or two — see
[`interpret-stats.md`](interpret-stats.md).

Under `evals/weekly/<date>/`:

- **`manifest.csv`** — one row per run: `prompt, skill_family, skill_leaf, model,
  condition, rep, run_id, exit_code, skills_sha, timestamp, skill_available,
  skill_activation, reached_leaf, fetched_site, fetched_count, model_snapshot,
  cli_version, total_cost_usd, num_turns, result_subtype, budget_hit, signals_ok,
  duration_ms`. The runner writes the first ten (base) columns;
  `extract-run-signals.sh` derives the rest from each transcript. `budget_hit` is `1` when the run hit the per-run
  spend cap (`result_subtype = error_max_budget_usd`): such a run is truncated, so
  it is excluded from scoring and the cost mean and reported as budget-capped.
  `signals_ok` is `0` when the transcript did not parse into the expected shape (a
  format break, not a real `activation=none`): the run's activation/fetch fields
  are then untrustworthy and the run is surfaced in Run health for investigation
  rather than silently read as a trigger miss.
  `skill_family` is the installed/availability unit and `skill_leaf` the prompt's
  target SKILL.md (so `reached_leaf` records whether progressive disclosure
  actually fired); `fetched_site`/`fetched_count` replace a raw URL list and count
  reaches to `skills.qdrant.tech`, net of denied attempts; `total_cost_usd` and
  `num_turns` are the per-run efficiency signals, straight from the result event;
  `duration_ms` is the run's wall-clock duration (also from the result event),
  aggregated into the scorecard's generation-time stats.
- **`scores.csv`** — one row per graded rubric item: `prompt, skill, model,
  condition, rep, item_type, item_text, verdict, credit, contribution,
  contested, evidence_quote`. This is the raw grade ledger; everything else is
  derived from it.
- **`scorecard.md`** — the human-facing weekly report:
  - top line: **lift per model** (Sonnet, Haiku), the must-coverage lift shown as
    **`lift ± SE`** with a **95% CI ≠ 0?** flag, each paired with a **cost delta**
    and **turns delta** (with-skill minus no-skill). The `± SE` is one *within-week*
    standard error of the paired per-prompt must-coverage lift (`stdev(dᵢ)/√n`,
    `dᵢ = must_cov_with(i) − must_cov_no(i)`): it measures this week's sampling
    uncertainty — the finite prompt set plus folded-in rep/judge noise — and
    **not** between-week drift. The flag reports whether the `t·SE` 95% interval
    excludes zero; `no` means the lift is not distinguishable from zero this week,
    so don't act on it. Available from week one (needs no history). Alongside it,
    **`Δbonus`** and **`Δavoid`** (with-skill minus no-skill) appear only when
    nonzero. The blended `composite` is deliberately **not** lifted in the headline:
    differencing a clamped 0–1 score misleads (a treatment already at the 1.0
    ceiling loses bonus credit the baseline still counts), so `must_coverage` lift
    plus the raw `Δbonus`/`Δavoid` carry the quality signal; `composite` stays a
    per-cell ranking score only.
  - **week-over-week lift delta** vs the previous run. The don't-act threshold is
    **`max(t·SE_Δ, between-week σ)`** — a movement must clear *both* the two weeks'
    combined sampling error (`SE_Δ = √(SE_now² + SE_prev²)`) *and* the observed
    week-to-week drift (`σ` of prior weekly lifts). Until four runs of history
    exist it reads `Will be computed after four runs.` — the between-week σ needs
    prior runs to exist (the within-week SE is already shown). Backed by a
    persistent, idempotent `scorecard-history.csv` (one upserted row per run,
    carrying each run's lift and its SE).
  - per-cell table: `must_coverage`, `bonus_rate`, `avoid_violations`, composite,
    plus mean `cost` and mean `num_turns`.
  - per-prompt table (one row per prompt/skill), so a regression is traceable to a specific skill
  - **activation / trigger-miss summary** — per-prompt activation breakdown and
    `reached_leaf` rate on the with-skill arm, with headline counts of *trigger
    misses* (`activation=none`: skill present but never reached, so a low lift is a
    triggering bug to fix in the skill's description, not a content bug) and
    *web_fetch-sourced* runs (lift came from the published copy, not the local
    `SKILL.md` under test). A prompt that never triggers is flagged.
  - **lift caveat — baseline self-served** — how many `no-skill` runs fetched
    `skills.qdrant.tech`, and which prompts; for those, lift is measured against a
    baseline that reached the published skill on its own, so it understates value.
  - **`avoid` violation detail** — the actual violated items with model, condition,
    and the evidence quote, not just a count, because fabrications are the most
    damaging failures and deserve names.
  - **coverage** — `graded X of Y` runs, and every dropped run listed with its
    reason (invalid install / errored / no gradeable answer). A partial run must
    not read as a clean one (refer to the No silent caps guardrail).
  - **cost & time** — actual spend (not the cost *mean*): generation `$` (per
    model) + **Opus judge `$`** (summed from each run's `judge_cost.txt`) + grand
    total; and generation timing — compute-time (Σ per-run `duration_ms`, with
    mean/median/max) and wall-clock, whose ratio is the **parallel speedup** from
    `--jobs`. Answers "what did this run cost and how long did it take".
  - contested-item and harness-failure counts.
  - **provenance** — exact resolved model snapshot string per model label, CLI
    version(s), skills commit(s), and the UTC run window (the only correlate for a
    silent build swap behind a floating alias); mismatches are flagged.

  **Efficiency companion (cost & turns).** Lift measures answer quality; it is
  near-zero for a strong model that already knows the material. A skill can still
  earn its keep by reaching the right answer *sooner* — fewer turns, fewer web
  round-trips, lower cost — so the scorecard reports a per-model **cost delta** and
  **turns delta** beside lift, and mean cost/turns per prompt. The delta is signed
  and cuts both ways: a skill may lower cost (less flailing/searching) or raise it
  (progressive-disclosure reads plus the skill's own context footprint), and both
  are informative when read next to lift — a flat lift with a negative cost delta
  is a skill worth keeping. Three rules keep it honest: it is a **within-model**
  comparison only (cost is model-priced, like lift); **budget-capped or errored
  runs are excluded** from the cost mean (their cost is a truncated floor, not the
  real figure); and `num_turns` is the cleaner "sooner" signal because, unlike
  cost, it is not inflated by the skill's context size. Reported, never gated.

## Guardrails

- **The judge is the linchpin.** Before trusting any number, dry-run the judge on
  a handful of existing `runs/` transcripts and confirm its grades match a
  human's. If the judge and a human disagree, the framework is measuring noise.
- **Rubrics need an owner other than the skill author.** A rubric written from
  `SKILL.md` measures conformity to the skill, including where the skill is
  wrong.
- **Baseline is not zero.** Sonnet and Haiku already know real material from
  pretraining and both arms can read the docs, so `no-skill` scores will be
  well above zero. That is expected: the signal is the lift, not the baseline.
- **Fabrications are the most damaging `avoid` violations.** A hallucinated
  endpoint, metric, or config key is a harm, penalized through the graded `−0.25`
  avoid term rather than gated, because we have no trustworthy way to detect
  fabrication reliably yet (refer to Thresholds And Gating).
- **No silent caps.** If a week's run drops prompts (timeouts, budget, invalid
  runs), the scorecard states which and how many. A partial run must not read as
  a clean one.
  