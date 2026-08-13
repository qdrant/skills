# Interpreting the Scorecard and `scores.csv`

A plain-language glossary of every number the weekly run reports. Companion to `SCORING.md`, which explains the method; this file just says what each field means.

## TL;DR

The scorecard answers three questions for each skill, **per model** (a skill lifts a small model more than a large one):

1. **Does the skill improve the answer?**: *lift* (quality with the skill minus
   without).
2. **Does it also get there cheaper/sooner?**: *cost delta* and *turns delta*.
3. **Can we trust the number?**: *± SE* and the *week-over-week noise floor* (is it real or sampling noise), *activation* (was the skill actually used), *coverage* (what was dropped), and *provenance* (exactly what produced it).

Quality is on a 0–1 scale (read as a percentage). Nothing is gated — it is a report.

---

## Scorecard

### Lift per model

- `model`: which model.
- `must_coverage no→with`: share of required points covered, baseline → with-skill.
- `must lift ± SE`: the improvement, ± one within-week standard error (this week's sampling uncertainty, not drift).
- `95% CI != 0?`: is the lift distinguishable from zero this week? `no` = don't act on it yet.
- `Δbonus` / `Δavoid`: change in bonus depth / avoid-violation count with the skill; each column appears only when nonzero. (Composite is not lifted here — differencing the clamped score misleads; see per-cell `composite` for ranking.)
- `Δcost ($)`: dollars per run added/saved by the skill; negative = cheaper.
- `Δturns`: conversation messages added/saved; negative = fewer. Counts all messages (model turns + tool-result messages), not just the model's own turns.

### Week-over-week lift delta

- placeholder: reads `Will be computed after four runs.` until four runs of history exist.
- `must lift (prev → now)`: last run's lift → this run's.
- `Δ`: the change between them.
- `t·SE_Δ (within)`: how big a change this week's sampling noise alone could explain.
- `σ (between)`: observed week-to-week bounce from prior runs (drift + prompt resampling).
- `threshold`: `max` of the two; the don't-act line.
- `actionable?`: is `|Δ|` above the threshold? `no (within noise)` = ignore it.

### Per-cell metrics

One row per model × condition (a "cell").

- `must_cov`: must-coverage; primary quality.
- `bonus_rate`: share of nice-to-have points hit; depth.
- `avoid_viol`: average count of harmful things done; `0` = none.
- `composite`: blended score (must_coverage + 0.10 × bonus_rate − 0.25 × avoid_violations, then clamped 0–1)
- `mean cost`: average $/run.
- `mean turns`: average conversation messages/run (model turns + tool results).
- `n`: prompts in the cell.

### Per-prompt

Traces a regression to a specific skill.

- `must no→with`: this prompt's must-coverage, baseline → with-skill.
- `must lift`: this prompt's improvement.
- `comp no→with`: this prompt's composite, baseline → with-skill.

### Activation / trigger misses

- `with-skill runs`: count.
- `trigger misses`: with-skill runs where the skill was present but never reached. A low lift here is a triggering (description) bug, not a content bug.
- `web_fetch-sourced`: runs whose lift came from the published site, not the local `SKILL.md` under test.
- `activations (with-skill)`: how the skill was reached and how often: `skill_tool` (progressive disclosure), `file_read` (read the file), `web_fetch` (published copy), `none`.
- `reached leaf`: runs that read the prompt's exact target `SKILL.md`; whether progressive disclosure actually fired.

### Lift caveat — baseline self-served

- `no-skill runs that fetched skills.qdrant.tech`: baselines that reached the published skill on their own. Their lift is understated (the baseline effectively had the skill).

### `avoid` violations

- One row per actual violation, with `model`, `condition`, the violated item, and the quoted `evidence`. Fabrications live here; the most damaging failures, given names not just a count.

### Coverage

- `runs graded`: how many of the attempted runs were actually scored (`X of Y`).
- `dropped`: runs excluded, each with a reason (`budget-capped (truncated)` / `invalid: skill unavailable` / `errored` / `no gradeable answer`). Stops a partial week from reading as a clean one.

### Cost & time

- `generation`: actual dollars spent on the generation runs (all of them, incl. truncated ones that still cost), broken down per model — not the cost *mean*.
- `judge (Opus)`: dollars spent grading, summed from each run's `judge_cost.txt`.
- `total`: generation + judge — what this run cost end to end.
- `compute-time (Σ per-run)`: sum of per-run wall durations, with mean/median/max.
- `wall-clock`: elapsed time of the generation phase; `compute-time ÷ wall-clock` is the **parallel speedup** delivered by `--jobs`.

### Run health

- `contested items`: items where two judge samples disagreed; the rubric-ambiguity backlog.
- `ungraded items`: items the judge returned no parseable verdict for.
- `budget-capped runs`: runs that hit the per-run $ cap and were truncated; excluded from scoring and the cost mean.
- `runs with unreliable signals`: runs whose transcript did not parse to the expected shape (`signals_ok=0`) — a format break, so their activation/fetch numbers are suspect and flagged for investigation rather than read as a trigger miss.
- `runs excluded from the cost mean`: errored/capped runs left out of the cost average (their cost is a truncated floor).

### Provenance

- `exact snapshot string`: the model build each label resolved to (for example, `claude-haiku-4-5-20251001`).
- `CLI version(s)`: Claude Code version(s) the runs used.
- `skills commit(s)`: the skills-tree commit under test.
- `run window (UTC)`: when the runs happened; the only correlate for a silent build swap behind a floating alias.

---

## `scores.csv` (raw grade ledger — one row per graded rubric item)

- `prompt`: the test prompt (one per skill).
- `skill`: the installed skill family.
- `model`: model label.
- `condition`: `no-skill` or `with-skill`.
- `rep`: repetition index.
- `item_type`: `must` (required), `bonus` (nice-to-have), `avoid` (must not do).
- `item_text`: the rubric item being graded.
- `verdict`: `met`/`missing` (must), `met`/`absent` (bonus), `violated`/`clean` (avoid); `PARSE_ERROR` if the judge output could not be parsed.
- `credit`: `0` or `1`. Note inverted polarity for `avoid`: `1` = violated = bad.
- `contribution`: signed credit (`avoid` is negative), so summing across item types cannot silently produce nonsense.
- `contested`: set when two judge samples disagreed on this item.
- `evidence_quote`: the span the judge quoted from the answer to justify a `met`/`violated` verdict.
