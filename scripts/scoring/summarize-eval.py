#!/usr/bin/env python3
"""Aggregate a weekly run into the lift + efficiency scorecard.

Reads scores.csv (graded item ledger) and manifest.csv (per-run signals incl.
cost/turns/activation) from a weekly dir, aggregates in the SCORING.md order

    item  ->  prompt x rep  ->  prompt  ->  cell (model x condition)

as a flat per-prompt macro-average, and writes scorecard.md with:
  - lift per model (must_coverage + composite) + cost/turns delta
  - week-over-week lift delta (placeholder until four runs of history exist)
  - per-cell and per-prompt tables
  - activation / trigger-miss summary (why a lift is what it is)
  - lift caveats: baseline runs that self-served the skill via the site
  - avoid-violation detail (the most damaging failures, with evidence)
  - coverage: how many prompts scored, and every dropped run with its reason
  - run health + provenance (exact model strings, versions, run window)

Quality comes from scores.csv; cost/turns/activation from manifest.csv. Deltas
are within-model only; nothing here gates.
"""
from __future__ import annotations

import argparse
import csv
import math
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean, median, pstdev, stdev

MODELS_ORDER = ["sonnet", "haiku"]
CONDITIONS = ["no-skill", "with-skill"]
UNGRADED = {"", "PARSE_ERROR"}
WOW_MIN_RUNS = 4  # need this many runs of history before a WoW delta is meaningful


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def fmt(x, nd=3):
    return "n/a" if x is None else f"{x:.{nd}f}"


def signed(x, nd=3):
    return "n/a" if x is None else f"{x:+.{nd}f}"


def md_table(headers, rows):
    """Render a GitHub-markdown table with padded, aligned columns so it is
    readable as raw text (and still renders normally). Cells are plain strings —
    avoid markdown emphasis (**bold**) inside them, which would misalign the raw
    view. Returns a list of lines."""
    rows = [[str(c) for c in r] for r in rows]
    widths = [len(h) for h in headers]
    for r in rows:
        for i, c in enumerate(r):
            widths[i] = max(widths[i], len(c))

    def line(cells):
        return "| " + " | ".join(c.ljust(widths[i]) for i, c in enumerate(cells)) + " |"

    out = [line(headers), "| " + " | ".join("-" * w for w in widths) + " |"]
    out += [line(r) for r in rows]
    return out


# --- load ------------------------------------------------------------------


def load_csv(path: Path):
    with path.open() as f:
        return list(csv.DictReader(f))


# --- quality aggregation ---------------------------------------------------


def rep_metrics(items):
    must = [float(i["credit"]) for i in items if i["item_type"] == "must"]
    bonus = [float(i["credit"]) for i in items if i["item_type"] == "bonus"]
    avoid = [float(i["credit"]) for i in items if i["item_type"] == "avoid"]
    must_cov = mean(must) if must else None
    bonus_rate = mean(bonus) if bonus else None
    avoid_viol = sum(avoid)
    composite = None
    if must_cov is not None:
        composite = clamp(must_cov + 0.10 * (bonus_rate or 0.0) - 0.25 * avoid_viol, 0.0, 1.0)
    return {"must_coverage": must_cov, "bonus_rate": bonus_rate,
            "avoid_violations": avoid_viol, "composite": composite}


def avg_metric(dicts, key):
    vals = [d[key] for d in dicts if d.get(key) is not None]
    return mean(vals) if vals else None


def aggregate_quality(scores):
    by_rep = defaultdict(list)
    contested = ungraded = 0
    for r in scores:
        by_rep[(r["model"], r["condition"], r["prompt"], r["rep"])].append(r)
        if r.get("contested") not in (None, "", "False", "false"):
            contested += 1
        if r["verdict"] in UNGRADED:
            ungraded += 1
    rep_level = {k: rep_metrics(v) for k, v in by_rep.items()}

    by_prompt = defaultdict(list)
    for (model, cond, prompt, _rep), m in rep_level.items():
        by_prompt[(model, cond, prompt)].append(m)
    prompt_level = {
        key: {k: avg_metric(ms, k) for k in
              ("must_coverage", "bonus_rate", "avoid_violations", "composite")}
        for key, ms in by_prompt.items()
    }

    by_cell = defaultdict(list)
    for (model, cond, _prompt), m in prompt_level.items():
        by_cell[(model, cond)].append(m)
    cell_level = {}
    for key, ms in by_cell.items():
        cell_level[key] = {k: avg_metric(ms, k) for k in
                           ("must_coverage", "bonus_rate", "avoid_violations", "composite")}
        cell_level[key]["n_prompts"] = len(ms)
    return prompt_level, cell_level, contested, ungraded


# --- cost aggregation ------------------------------------------------------


def aggregate_cost(manifest):
    by_cell = defaultdict(lambda: {"cost": [], "turns": []})
    excluded = 0
    for r in manifest:
        # Errored or budget-capped runs are truncated: their cost is a floor, not
        # the real figure, so they never enter the cost mean.
        if r.get("exit_code") != "0" or r.get("budget_hit") == "1":
            excluded += 1
            continue
        cost, turns = r.get("total_cost_usd", ""), r.get("num_turns", "")
        if cost in (None, ""):
            excluded += 1
            continue
        key = (r.get("model"), r.get("condition"))
        by_cell[key]["cost"].append(float(cost))
        if turns not in (None, ""):
            by_cell[key]["turns"].append(float(turns))
    cell = {}
    for key, v in by_cell.items():
        cell[key] = {"cost": mean(v["cost"]) if v["cost"] else None,
                     "turns": mean(v["turns"]) if v["turns"] else None, "n": len(v["cost"])}
    return cell, excluded


def delta(withv, nov):
    return None if withv is None or nov is None else withv - nov


# Two-sided 95% Student-t multipliers by degrees of freedom. Small n here (a
# handful to ~26 prompts), so z=1.96 would overstate confidence — use t.
_T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365,
        8: 2.306, 9: 2.262, 10: 2.228, 12: 2.179, 15: 2.131, 20: 2.086,
        25: 2.060, 30: 2.042, 40: 2.021, 60: 2.000, 120: 1.980}


def t95(df):
    """95% two-sided t multiplier; conservative (largest tabulated df <= df)."""
    if df < 1:
        return None
    if df >= 120:
        return 1.960
    best = max((k for k in _T95 if k <= df), default=min(_T95))
    return _T95[best]


def within_week_se(prompt_q, models):
    """Within-week paired standard error of the must_coverage lift, per model.

    For each prompt present in BOTH arms, dᵢ = must_cov_with − must_cov_no; the
    lift is mean(dᵢ) and SE = stdev(dᵢ)/√n. Pairing cancels between-prompt
    difficulty. This measures ONLY this week's sampling uncertainty (the finite
    prompt set + folded-in rep/judge noise) — not between-week drift. The CI is
    used to flag whether the lift is distinguishable from zero this week."""
    out = {}
    for m in models:
        prompts = {p for (mm, _c, p) in prompt_q if mm == m}
        ds = []
        for p in prompts:
            no = prompt_q.get((m, "no-skill", p))
            wi = prompt_q.get((m, "with-skill", p))
            if not no or not wi:
                continue
            a, b = no.get("must_coverage"), wi.get("must_coverage")
            if a is None or b is None:
                continue
            ds.append(b - a)
        n = len(ds)
        if n >= 2:
            lift = mean(ds)
            se = stdev(ds) / math.sqrt(n)
            t = t95(n - 1)
            half = t * se if t else None
            excludes_zero = half is not None and abs(lift) > half
        else:
            lift = ds[0] if n == 1 else None
            se = half = t = None
            excludes_zero = False
        out[m] = {"lift": lift, "se": se, "n": n, "half": half, "excludes_zero": excludes_zero}
    return out


def per_model_lifts(cell_q, cell_cost, models):
    out = {}
    for m in models:
        qn, qw = cell_q.get((m, "no-skill"), {}), cell_q.get((m, "with-skill"), {})
        cn, cw = cell_cost.get((m, "no-skill"), {}), cell_cost.get((m, "with-skill"), {})
        out[m] = {
            "must_lift": delta(qw.get("must_coverage"), qn.get("must_coverage")),
            # composite_lift kept for history continuity only — not shown in the
            # headline: differencing the clamped composite is misleading (a treatment
            # at the 1.0 ceiling loses bonus credit the baseline keeps). Use must_lift
            # plus the raw bonus/avoid deltas instead.
            "composite_lift": delta(qw.get("composite"), qn.get("composite")),
            "bonus_delta": delta(qw.get("bonus_rate"), qn.get("bonus_rate")),
            "avoid_delta": delta(qw.get("avoid_violations"), qn.get("avoid_violations")),
            "cost_delta": delta(cw.get("cost"), cn.get("cost")),
            "turns_delta": delta(cw.get("turns"), cn.get("turns")),
        }
    return out


# --- provenance ------------------------------------------------------------


def provenance(manifest):
    snaps = defaultdict(set)
    cli, sha, stamps = set(), set(), set()
    for r in manifest:
        ms = (r.get("model_snapshot") or "").strip()
        if ms and ms != "MISSING_TRANSCRIPT":
            snaps[(r.get("model") or "").strip()].add(ms)
        for field, bucket in (("cli_version", cli), ("skills_sha", sha), ("timestamp", stamps)):
            v = (r.get(field) or "").strip()
            if v:
                bucket.add(v)
    window = (min(stamps), max(stamps)) if stamps else None
    return snaps, cli, sha, window


# --- new sections ----------------------------------------------------------


def _stamp_epoch(ts):
    """Parse a run's YYYYmmddTHHMMSSZ start timestamp to epoch seconds."""
    try:
        return datetime.strptime(ts, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc).timestamp()
    except (ValueError, TypeError):
        return None


def cost_time_section(weekdir, manifest):
    """Total spend (generation + Opus judge) and generation timing — the run's
    money/time summary. Spend is actual dollars spent (all runs, incl. truncated
    ones that still cost), not the cost *mean*. Judge spend is read from each
    run's judge_cost.txt; generation timing from manifest duration_ms + start."""
    L = ["## Cost & time\n"]

    gen_by_model = defaultdict(float)
    gen_total = 0.0
    for r in manifest:
        c = r.get("total_cost_usd", "")
        if c in ("", None):
            continue
        try:
            v = float(c)
        except ValueError:
            continue
        gen_total += v
        gen_by_model[r.get("model", "?")] += v

    judge_total = 0.0
    for r in manifest:
        f = weekdir / (r.get("run_id") or "") / "judge_cost.txt"
        if f.exists():
            try:
                judge_total += float(f.read_text().strip())
            except ValueError:
                pass

    grand = gen_total + judge_total
    by_model_str = ", ".join(f"{m} ${gen_by_model[m]:.2f}" for m in sorted(gen_by_model)) or "n/a"
    L.append("**Spend (actual $ spent, all runs):**")
    L.append(f"- generation: ${gen_total:.2f}  ({by_model_str})")
    L.append(f"- judge (Opus): ${judge_total:.2f}")
    L.append(f"- **total: ${grand:.2f}**")
    L.append("")

    durs, starts, finishes = [], [], []
    for r in manifest:
        d = r.get("duration_ms", "")
        if d in ("", None):
            continue
        try:
            ds = float(d) / 1000.0
        except ValueError:
            continue
        durs.append(ds)
        e = _stamp_epoch(r.get("timestamp", ""))
        if e is not None:
            starts.append(e)
            finishes.append(e + ds)
    L.append("**Time (generation phase):**")
    if durs:
        compute = sum(durs)
        L.append(f"- runs timed: {len(durs)}")
        L.append(f"- compute-time (Σ per-run): {compute/60:.1f} min  "
                 f"(mean {mean(durs):.0f}s, median {median(durs):.0f}s, max {max(durs):.0f}s)")
        if starts and finishes:
            wall = max(finishes) - min(starts)
            speed = f"  (parallel speedup ~{compute/wall:.1f}×)" if wall > 0 else ""
            L.append(f"- wall-clock: {wall/60:.1f} min{speed}")
    else:
        L.append("- (no per-run durations recorded)")
    L.append("")
    return L


def models_present(cell_q, cell_cost):
    seen = {m for (m, _c) in cell_q} | {m for (m, _c) in cell_cost}
    return [m for m in MODELS_ORDER if m in seen] + sorted(m for m in seen if m not in MODELS_ORDER)


def activation_section(manifest):
    ws = [r for r in manifest if r.get("condition") == "with-skill"]
    L = ["## Activation / trigger misses\n"]
    if not ws:
        L.append("_No with-skill runs._\n")
        return L
    miss = sum(1 for r in ws if r.get("skill_activation") == "none")
    webf = sum(1 for r in ws if r.get("skill_activation") == "web_fetch")
    L.append(f"- with-skill runs: **{len(ws)}**")
    L.append(f"- **trigger misses** (activation=none — skill present but never reached): **{miss}**")
    L.append(f"- lift sourced from the published site (activation=web_fetch, not the local SKILL.md): **{webf}**")
    L.append("")
    by_prompt = defaultdict(list)
    for r in ws:
        by_prompt[r.get("prompt")].append(r)
    trows = []
    for prompt in sorted(by_prompt):
        runs = by_prompt[prompt]
        acts = Counter(r.get("skill_activation") for r in runs)
        acts_str = ", ".join(f"{k}×{v}" for k, v in sorted(acts.items()))
        leaf = sum(1 for r in runs if r.get("reached_leaf") == "1")
        flag = "  ⚠ never triggered" if acts.get("none", 0) == len(runs) else ""
        trows.append([prompt, f"{acts_str}{flag}", f"{leaf}/{len(runs)}"])
    L += md_table(["prompt", "activations (with-skill)", "reached leaf"], trows)
    L.append("")
    return L


def baseline_selfserved_section(manifest):
    ns = [r for r in manifest if r.get("condition") == "no-skill"]
    served = [r for r in ns if r.get("fetched_site") == "1"]
    L = ["## Lift caveat — baseline self-served the skill\n"]
    if not ns:
        L.append("_No no-skill runs._\n")
        return L
    L.append(f"- no-skill runs that fetched `skills.qdrant.tech`: **{len(served)} of {len(ns)}**")
    if served:
        prompts = sorted({r.get("prompt") for r in served})
        L.append(f"- affected prompts: {', '.join(prompts)}")
        L.append("- For these, lift is measured against a baseline that reached the "
                 "published skill on its own — so it *understates* the skill's value.")
    L.append("")
    return L


def avoid_section(scores):
    viol = [r for r in scores if r["item_type"] == "avoid"
            and r["verdict"] == "violated" and float(r["credit"]) > 0]
    L = ["## `avoid` violations (most damaging failures)\n"]
    if not viol:
        L.append("_None._\n")
        return L
    trows = []
    for r in viol:
        ev = (r.get("evidence_quote") or "").replace("|", "\\|")[:120]
        trows.append([r['prompt'], r['model'], r['condition'], r['item_text'][:80], ev])
    L += md_table(["prompt", "model", "condition", "violated item", "evidence"], trows)
    L.append("")
    return L


def coverage_section(manifest, scores):
    graded = {(r["prompt"], r["model"], r["condition"], r["rep"]) for r in scores}
    dropped = []
    for r in manifest:
        key = (r.get("prompt"), r.get("model"), r.get("condition"), r.get("rep"))
        if key in graded:
            continue
        if r.get("budget_hit") == "1":
            reason = "budget-capped (truncated)"
        elif r.get("condition") == "with-skill" and r.get("skill_available") != "1":
            reason = "invalid: skill unavailable"
        elif r.get("exit_code") != "0":
            reason = f"errored (exit {r.get('exit_code')})"
        else:
            reason = "no gradeable answer"
        dropped.append((r.get("run_id"), r.get("prompt"), r.get("model"), r.get("condition"), reason))
    total = len(manifest)
    L = ["## Coverage\n"]
    L.append(f"- runs graded: **{len(graded)} of {total}**")
    if dropped:
        L.append(f"- dropped: **{len(dropped)}** (a partial run is not a clean run)")
        L.append("")
        L += md_table(["run_id", "prompt", "model", "condition", "reason"],
                      [[rid, p, m, c, reason] for rid, p, m, c, reason in dropped])
    else:
        L.append("- dropped: **0**")
    L.append("")
    return L


# --- week-over-week history ------------------------------------------------

HISTORY_COLS = ["run_key", "window_end", "model", "must_lift", "must_lift_se",
                "composite_lift", "cost_delta", "turns_delta"]


def load_history(path: Path):
    return load_csv(path) if path.exists() else []


def _num(v):
    return "" if v is None else f"{v:.6f}"


def upsert_history(path: Path, run_key, window_end, lifts, se_info):
    rows = [r for r in load_history(path) if r.get("run_key") != run_key]
    for model, v in lifts.items():
        rows.append({
            "run_key": run_key, "window_end": window_end or "", "model": model,
            "must_lift": _num(v["must_lift"]),
            "must_lift_se": _num(se_info.get(model, {}).get("se")),
            "composite_lift": _num(v["composite_lift"]),
            "cost_delta": _num(v["cost_delta"]),
            "turns_delta": _num(v["turns_delta"]),
        })
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=HISTORY_COLS)
        w.writeheader()
        w.writerows(rows)


def _fnum(v):
    return float(v) if v not in ("", None) else None


def wow_section(path: Path, run_key, current_lifts, se_info, models):
    rows = load_history(path)
    keys_sorted = sorted({r["run_key"] for r in rows},
                         key=lambda k: max((r["window_end"] for r in rows if r["run_key"] == k), default=""))
    n_runs = len(keys_sorted)  # includes the just-upserted current run
    L = ["## Week-over-week lift delta\n"]
    if n_runs < WOW_MIN_RUNS:
        L.append(f"**Will be computed after four runs.** (this is run {n_runs} of "
                 f"{WOW_MIN_RUNS}; a delta needs prior runs to estimate the between-week "
                 "noise floor. This week's own sampling uncertainty is in the lift table "
                 "above as ± SE.)\n")
        return L
    prior_keys = [k for k in keys_sorted if k != run_key]
    prev_key = prior_keys[-1]
    prev = {r["model"]: r for r in rows if r["run_key"] == prev_key}
    L.append(f"vs previous run `{prev_key}`. The don't-act threshold is "
             "**max(t·SE_Δ, between-week σ)** — a delta must clear both this week's "
             "sampling error *and* the observed week-to-week drift to be actionable.\n")
    trows = []
    for m in models:
        now = current_lifts.get(m, {}).get("must_lift")
        pv = _fnum(prev.get(m, {}).get("must_lift"))
        d = delta(now, pv)
        # within-week component: combine this week's and prev week's paired SE
        se_now = se_info.get(m, {}).get("se")
        se_prev = _fnum(prev.get(m, {}).get("must_lift_se"))
        within = None
        if se_now is not None and se_prev is not None:
            se_delta = math.sqrt(se_now ** 2 + se_prev ** 2)
            t = t95(se_info.get(m, {}).get("n", 1) - 1) or 1.96
            within = t * se_delta
        # between-week component: spread of prior weekly lifts
        hist = [_fnum(r["must_lift"]) for r in rows
                if r["model"] == m and r["run_key"] != run_key and r["must_lift"] not in ("", None)]
        between = pstdev(hist) if len(hist) >= 2 else None
        cands = [x for x in (within, between) if x is not None]
        threshold = max(cands) if cands else None
        if d is None or threshold is None:
            actionable = "n/a"
        else:
            actionable = "yes" if abs(d) > threshold else "no (within noise)"
        trows.append([m, f"{fmt(pv)} → {fmt(now)}", signed(d), fmt(within),
                      fmt(between), fmt(threshold), actionable])
    L += md_table(["model", "must lift (prev → now)", "Δ", "t·SE_Δ (within)",
                   "σ (between)", "threshold", "actionable?"], trows)
    L.append("")
    return L


# --- assemble --------------------------------------------------------------


def build_scorecard(weekdir, prompt_q, cell_q, cell_cost, contested, ungraded,
                    cost_excluded, prov, manifest, scores, wow_lines, current_lifts, se_info):
    models = models_present(cell_q, cell_cost)
    L = [f"# Weekly Skill Scorecard — {weekdir.name}\n"]

    # lift per model
    L.append("## Lift per model (with-skill − no-skill)\n")
    eps = 1e-9
    nz = lambda key: any(current_lifts[m].get(key) is not None and abs(current_lifts[m][key]) > eps
                         for m in models)
    show_bonus, show_avoid = nz("bonus_delta"), nz("avoid_delta")
    headers = ["model", "must_coverage no→with", "must lift ± SE", "95% CI != 0?"]
    if show_bonus:
        headers.append("Δbonus")
    if show_avoid:
        headers.append("Δavoid")
    headers += ["Δcost ($)", "Δturns"]
    rows = []
    for m in models:
        qn, qw = cell_q.get((m, "no-skill"), {}), cell_q.get((m, "with-skill"), {})
        v = current_lifts[m]
        se = se_info.get(m, {})
        arrow = f"{fmt(qn.get('must_coverage'))} → {fmt(qw.get('must_coverage'))}"
        se_str = f"{signed(v['must_lift'])} ± {fmt(se.get('se')) if se.get('se') is not None else 'n/a'}"
        flag = "n/a (need >=2 prompts)" if se.get("se") is None else \
            ("yes" if se.get("excludes_zero") else "no")
        row = [m, arrow, se_str, flag]
        if show_bonus:
            row.append(signed(v.get("bonus_delta")))
        if show_avoid:
            row.append(signed(v.get("avoid_delta"), 2))
        row += [signed(v['cost_delta'], 4), signed(v['turns_delta'], 1)]
        rows.append(row)
    L += md_table(headers, rows)
    L.append("\n_± SE is one within-week standard error of the paired per-prompt must-coverage "
             "lift — this week's sampling uncertainty (finite prompt set + run/judge noise), "
             "**not** between-week drift. '≠ 0?' asks whether the 95% CI (t·SE) excludes zero: "
             "'no' means don't act on this lift yet. Δbonus/Δavoid appear only when the skill "
             "changed bonus depth or introduced/removed a violation. Δcost/Δturns are "
             "within-model only; negative = cheaper/sooner. Note: turns counts all "
             "conversation messages, including tool-result messages, not just the model's "
             "own turns. Reported, not gated._\n")

    L += wow_lines

    # per-cell
    L.append("## Per-cell metrics\n")
    rows = []
    for m in models:
        for cond in CONDITIONS:
            q = cell_q.get((m, cond))
            if not q:
                continue
            c = cell_cost.get((m, cond), {})
            rows.append([m, cond, fmt(q['must_coverage']), fmt(q['bonus_rate']),
                         fmt(q['avoid_violations'], 2), fmt(q['composite']),
                         fmt(c.get('cost'), 4), fmt(c.get('turns'), 1), q['n_prompts']])
    L += md_table(["model", "condition", "must_cov", "bonus_rate", "avoid_viol",
                   "composite", "mean cost", "mean turns", "n"], rows)
    L.append("")

    # per-prompt
    L.append("## Per-prompt (must_coverage; with-skill lift)\n")
    rows = []
    for prompt in sorted({p for (_m, _c, p) in prompt_q}):
        for m in models:
            no, wi = prompt_q.get((m, "no-skill", prompt)), prompt_q.get((m, "with-skill", prompt))
            if not no and not wi:
                continue
            mc_no = no.get("must_coverage") if no else None
            mc_wi = wi.get("must_coverage") if wi else None
            cp_no = no.get("composite") if no else None
            cp_wi = wi.get("composite") if wi else None
            rows.append([prompt, m, f"{fmt(mc_no)} → {fmt(mc_wi)}",
                         signed(delta(mc_wi, mc_no)), f"{fmt(cp_no)} → {fmt(cp_wi)}"])
    L += md_table(["prompt", "model", "must no→with", "must lift", "comp no→with"], rows)
    L.append("")

    # new sections
    L += activation_section(manifest)
    L += baseline_selfserved_section(manifest)
    L += avoid_section(scores)
    L += coverage_section(manifest, scores)

    # cost & time summary
    L += cost_time_section(weekdir, manifest)

    # run health
    budget_capped = sum(1 for r in manifest if r.get("budget_hit") == "1")
    signals_bad = sum(1 for r in manifest if r.get("signals_ok") == "0")
    L.append("## Run health\n")
    L.append(f"- contested items: {contested}")
    L.append(f"- ungraded items (parse/verdict errors): {ungraded}")
    L.append(f"- budget-capped runs (hit the per-run $ cap, truncated, excluded): {budget_capped}")
    L.append(f"- runs with unreliable signals (signals_ok=0 — transcript did not parse "
             f"to the expected shape; activation/fetch numbers suspect, investigate): {signals_bad}")
    L.append(f"- runs excluded from the cost mean (errored/capped/no-cost): {cost_excluded}")
    L.append("")

    # provenance
    snaps, cli_v, sha_v, window = prov
    L.append("## Provenance\n")
    L.append("Exact model builds and versions these numbers were produced with:\n")
    prov_rows = []
    listed = list(models) + [m for m in sorted(snaps) if m not in set(models)]
    for m in listed:
        strings = sorted(snaps.get(m, []))
        if not strings:
            prov_rows.append([m, "(unknown)"])
        elif len(strings) == 1:
            prov_rows.append([m, f"`{strings[0]}`"])
        else:
            prov_rows.append([m, f"⚠ multiple (`{'`, `'.join(strings)}`) — model changed mid-week"])
    L += md_table(["model", "exact snapshot string"], prov_rows)
    L.append("")
    L.append(f"- CLI version(s): {', '.join(f'`{v}`' for v in sorted(cli_v)) or '_(unknown)_'}")
    L.append(f"- skills commit(s): {', '.join(f'`{v}`' for v in sorted(sha_v)) or '_(unknown)_'}")
    if window:
        lo, hi = window
        L.append(f"- run window (UTC): {'`'+lo+'`' if lo == hi else '`'+lo+'` – `'+hi+'`'}")
    if len(cli_v) > 1:
        L.append("- ⚠ more than one CLI version present — versions were not pinned across runs.")
    if len(sha_v) > 1:
        L.append("- ⚠ more than one skills commit present — the skills tree changed mid-week.")
    L.append("- Note: an alias like `claude-sonnet-5` can float to a newer build without "
             "changing name; the run window is the only correlate for such a silent swap. "
             "Pass a dated model id if byte-level pinning matters.")
    L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description="Aggregate a weekly run into scorecard.md")
    ap.add_argument("weekdir", type=Path, nargs="?", default=Path.cwd())
    ap.add_argument("--history", type=Path, default=None,
                    help="WoW history CSV (default: <weekdir>/../scorecard-history.csv)")
    args = ap.parse_args()

    weekdir = args.weekdir
    scores_path, manifest_path = weekdir / "scores.csv", weekdir / "manifest.csv"
    for p in (scores_path, manifest_path):
        if not p.exists():
            print(f"error: {p} not found", file=__import__("sys").stderr)
            return 2

    scores = load_csv(scores_path)
    manifest = load_csv(manifest_path)

    prompt_q, cell_q, contested, ungraded = aggregate_quality(scores)
    cell_cost, cost_excluded = aggregate_cost(manifest)
    prov = provenance(manifest)
    models = models_present(cell_q, cell_cost)
    current_lifts = per_model_lifts(cell_q, cell_cost, models)
    se_info = within_week_se(prompt_q, models)

    history_path = args.history or (weekdir.parent / "scorecard-history.csv")
    window_end = prov[3][1] if prov[3] else ""
    upsert_history(history_path, weekdir.name, window_end, current_lifts, se_info)
    wow_lines = wow_section(history_path, weekdir.name, current_lifts, se_info, models)

    report = build_scorecard(weekdir, prompt_q, cell_q, cell_cost, contested, ungraded,
                             cost_excluded, prov, manifest, scores, wow_lines, current_lifts, se_info)
    (weekdir / "scorecard.md").write_text(report)
    print(report)
    print(f"\nwrote {weekdir / 'scorecard.md'}  |  history: {history_path}",
          file=__import__("sys").stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
