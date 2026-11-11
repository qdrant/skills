#!/usr/bin/env python3
"""Compare two versions of the same skill (A vs B) scored by the weekly harness.

Unlike summarize-eval.py — which diffs `no-skill` vs `with-skill` within one
run to measure lift — this diffs two *separate* run directories that each used
the `with-skill` condition, one per skill version (e.g. main vs a PR branch).
Both directories are expected to be produced the normal way:

    run-eval-matrix.sh --conditions with-skill --skills-root <version> ...
    extract-run-signals.sh --out-dir <version-dir>
    judge-runs.sh --out-dir <version-dir>

against the *same* (matched) prompt subset, so every prompt in A has a
counterpart in B. Reuses SCORING.md's aggregation order

    item  ->  prompt x rep  ->  prompt  ->  model

and its paired within-run SE math, applied across the A/B pair instead of
across the no-skill/with-skill pair. Nothing here gates; it reports a scorecard.
"""
from __future__ import annotations

import argparse
import csv
import math
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean, stdev

# --- small helpers (duplicated from summarize-eval.py; these two scripts are
# each meant to run standalone, and the shared surface is small) ------------


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def fmt(x, nd=3):
    return "n/a" if x is None else f"{x:.{nd}f}"


def signed(x, nd=3):
    return "n/a" if x is None else f"{x:+.{nd}f}"


def md_table(headers, rows):
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


_T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365,
        8: 2.306, 9: 2.262, 10: 2.228, 12: 2.179, 15: 2.131, 20: 2.086,
        25: 2.060, 30: 2.042, 40: 2.021, 60: 2.000, 120: 1.980}


def t95(df):
    if df < 1:
        return None
    if df > 120:
        return 1.960
    best = max((k for k in _T95 if k <= df), default=min(_T95))
    return _T95[best]


def load_csv(path: Path):
    with path.open() as f:
        return list(csv.DictReader(f))


def delta(bv, av):
    return None if bv is None or av is None else bv - av


# --- quality aggregation (per version dir) ----------------------------------


UNGRADED = {"", "PARSE_ERROR"}


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
    """item -> prompt x rep -> prompt (per model). No condition axis: every row
    in `scores` is assumed to be one skill version's with-skill runs."""
    by_rep = defaultdict(list)
    contested = ungraded = 0
    for r in scores:
        by_rep[(r["model"], r["prompt"], r["rep"])].append(r)
        if r.get("contested") not in (None, "", "False", "false"):
            contested += 1
        if r["verdict"] in UNGRADED:
            ungraded += 1
    rep_level = {k: rep_metrics(v) for k, v in by_rep.items()}

    by_prompt = defaultdict(list)
    for (model, prompt, _rep), m in rep_level.items():
        by_prompt[(model, prompt)].append(m)
    prompt_level = {
        key: {k: avg_metric(ms, k) for k in
              ("must_coverage", "bonus_rate", "avoid_violations", "composite")}
        for key, ms in by_prompt.items()
    }

    by_model = defaultdict(list)
    for (model, _prompt), m in prompt_level.items():
        by_model[model].append(m)
    model_level = {m: {k: avg_metric(ms, k) for k in
                        ("must_coverage", "bonus_rate", "avoid_violations", "composite")}
                   for m, ms in by_model.items()}
    for m, ms in by_model.items():
        model_level[m]["n_prompts"] = len(ms)
    return prompt_level, model_level, contested, ungraded


def aggregate_cost(manifest):
    by_model = defaultdict(lambda: {"cost": [], "turns": []})
    excluded = 0
    for r in manifest:
        if r.get("exit_code") != "0" or r.get("budget_hit") == "1":
            excluded += 1
            continue
        cost, turns = r.get("total_cost_usd", ""), r.get("num_turns", "")
        if cost in (None, ""):
            excluded += 1
            continue
        by_model[r.get("model")]["cost"].append(float(cost))
        if turns not in (None, ""):
            by_model[r.get("model")]["turns"].append(float(turns))
    out = {}
    for m, v in by_model.items():
        out[m] = {"cost": mean(v["cost"]) if v["cost"] else None,
                  "turns": mean(v["turns"]) if v["turns"] else None, "n": len(v["cost"])}
    return out, excluded


LOCAL_ACTIVATION = {"skill_tool", "file_read"}


def activation_by_prompt(manifest, scores):
    """Per (model, prompt): how the graded runs reached the skill.

    Counts only runs that were graded (present in scores.csv), so the rates
    describe the same runs the must score comes from. `activated` means the run
    read the local SKILL.md of the version under test (skill_tool or
    file_read). `web_fetch` is counted apart: the site serves the published
    skill from main, so a web_fetch run never saw this version's edit. Runs
    whose transcript did not parse (signals_ok=0) are `unknown`, not misses.
    """
    graded = {(r["prompt"], r["model"], r["rep"]) for r in scores}
    out = defaultdict(lambda: {"n": 0, "activated": 0, "leaf": 0, "web_fetch": 0, "unknown": 0})
    for r in manifest:
        key = (r.get("prompt"), r.get("model"), r.get("rep"))
        if key not in graded:
            continue
        c = out[(r.get("model"), r.get("prompt"))]
        c["n"] += 1
        if r.get("signals_ok", "1") == "0":
            c["unknown"] += 1
            continue
        act = r.get("skill_activation")
        if act in LOCAL_ACTIVATION:
            c["activated"] += 1
        elif act == "web_fetch":
            c["web_fetch"] += 1
        if r.get("reached_leaf") == "1":
            c["leaf"] += 1
    return dict(out)


def activation_by_model(act):
    out = defaultdict(lambda: {"n": 0, "activated": 0, "leaf": 0, "web_fetch": 0, "unknown": 0})
    for (model, _prompt), c in act.items():
        for k, v in c.items():
            out[model][k] += v
    return dict(out)


def fmt_activation(c):
    """`activated/n`, plus web_fetch and unparsed runs when present."""
    if not c or not c["n"]:
        return "n/a"
    s = f"{c['activated']}/{c['n']}"
    extra = []
    if c["web_fetch"]:
        extra.append(f"{c['web_fetch']} web_fetch")
    if c["unknown"]:
        extra.append(f"{c['unknown']} unparsed")
    return s + (f" ({', '.join(extra)})" if extra else "")


def fmt_leaf(c):
    if not c or not c["n"]:
        return "n/a"
    return f"{c['leaf']}/{c['n']}"


def never_activated(ca, cb):
    """True when neither version read the local skill in any parseable graded
    run, so the prompt's delta can't come from the skill edit."""
    runs = [c for c in (ca, cb) if c and c["n"]]
    return bool(runs) and all(c["activated"] == 0 and c["unknown"] < c["n"] for c in runs)


def paired_se(prompt_q_a, prompt_q_b, models):
    """Paired within-run SE of the must_coverage delta (B - A), per model. Same
    math as summarize-eval.py's within_week_se, but pairing A/B per prompt
    instead of no-skill/with-skill per prompt."""
    out = {}
    for m in models:
        prompts = {p for (mm, p) in prompt_q_a if mm == m} & {p for (mm, p) in prompt_q_b if mm == m}
        ds = []
        for p in prompts:
            a, b = prompt_q_a.get((m, p)), prompt_q_b.get((m, p))
            if not a or not b:
                continue
            av, bv = a.get("must_coverage"), b.get("must_coverage")
            if av is None or bv is None:
                continue
            ds.append(bv - av)
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
        out[m] = {"delta": lift, "se": se, "n": n, "half": half, "excludes_zero": excludes_zero}
    return out


def models_present(*model_dicts):
    order = ["sonnet", "haiku"]
    seen = set()
    for d in model_dicts:
        seen |= set(d)
    return [m for m in order if m in seen] + sorted(m for m in seen if m not in order)


def coverage_lines(label, manifest, scores):
    graded = {(r["prompt"], r["model"], r["rep"]) for r in scores}
    dropped = []
    for r in manifest:
        key = (r.get("prompt"), r.get("model"), r.get("rep"))
        if key in graded:
            continue
        if r.get("budget_hit") == "1":
            reason = "budget-capped (truncated)"
        elif r.get("skill_available") != "1":
            reason = "invalid: skill unavailable"
        elif r.get("exit_code") != "0":
            reason = f"errored (exit {r.get('exit_code')})"
        else:
            reason = "no gradeable answer"
        dropped.append((r.get("run_id"), r.get("prompt"), r.get("model"), reason))
    L = [f"**{label}**: graded {len(graded)} of {len(manifest)}"]
    if dropped:
        L.append("")
        L += md_table(["run_id", "prompt", "model", "reason"], dropped)
    return L


def avoid_lines(label, scores):
    viol = [r for r in scores if r["item_type"] == "avoid"
            and r["verdict"] == "violated" and float(r["credit"]) > 0]
    if not viol:
        return [f"**{label}**: none"]
    rows = [[r["prompt"], r["model"], r["item_text"][:80],
              (r.get("evidence_quote") or "").replace("|", "\\|")[:120]] for r in viol]
    return [f"**{label}**:", ""] + md_table(["prompt", "model", "violated item", "evidence"], rows)


def provenance_lines(label, manifest):
    sha = {(r.get("skills_sha") or "").strip() for r in manifest if r.get("skills_sha")}
    cli = {(r.get("cli_version") or "").strip() for r in manifest if r.get("cli_version")}
    return [f"- **{label}** — skills commit(s): {', '.join(f'`{v}`' for v in sorted(sha)) or '_(unknown)_'}, "
            f"CLI: {', '.join(f'`{v}`' for v in sorted(cli)) or '_(unknown)_'}"]


def build_scorecard(dir_a, dir_b, label_a, label_b,
                     pq_a, pq_b, mq_a, mq_b, cost_a, cost_b,
                     manifest_a, manifest_b, scores_a, scores_b):
    models = models_present(mq_a, mq_b)
    se_info = paired_se(pq_a, pq_b, models)
    act_a = activation_by_prompt(manifest_a, scores_a)
    act_b = activation_by_prompt(manifest_b, scores_b)
    mact_a, mact_b = activation_by_model(act_a), activation_by_model(act_b)

    L = [f"# Skill A/B Scorecard\n",
         f"**A** = `{label_a}` (`{dir_a}`)  \n**B** = `{label_b}` (`{dir_b}`)\n"]

    L.append("## Lift per model (B - A)\n")
    eps = 1e-9
    def nz(key):
        def val(d, m):
            v = d.get(m, {}).get(key)
            return 0.0 if v is None else v
        return any(abs(val(mq_b, m) - val(mq_a, m)) > eps for m in models)

    show_bonus, show_avoid = nz("bonus_rate"), nz("avoid_violations")
    headers = ["model", "must_coverage A -> B", "delta +/- SE", "95% CI != 0?"]
    if show_bonus:
        headers.append("d_bonus")
    if show_avoid:
        headers.append("d_avoid")
    headers += ["d_cost ($)", "d_turns"]
    rows = []
    for m in models:
        a, b = mq_a.get(m, {}), mq_b.get(m, {})
        ca, cb = cost_a.get(m, {}), cost_b.get(m, {})
        se = se_info.get(m, {})
        arrow = f"{fmt(a.get('must_coverage'))} -> {fmt(b.get('must_coverage'))}"
        se_str = f"{signed(se.get('delta'))} +/- {fmt(se.get('se')) if se.get('se') is not None else 'n/a'}"
        flag = "n/a (need >=2 prompts)" if se.get("se") is None else \
            ("yes" if se.get("excludes_zero") else "no")
        row = [m, arrow, se_str, flag]
        if show_bonus:
            row.append(signed(delta(b.get("bonus_rate"), a.get("bonus_rate"))))
        if show_avoid:
            row.append(signed(delta(b.get("avoid_violations"), a.get("avoid_violations")), 2))
        row += [signed(delta(cb.get("cost"), ca.get("cost")), 4),
                signed(delta(cb.get("turns"), ca.get("turns")), 1)]
        rows.append(row)
    L += md_table(headers, rows)
    L.append("\n_+/- SE is one within-run standard error of the paired per-prompt must-coverage "
             "delta (B - A) - sampling uncertainty from this prompt set and rep/judge noise, not "
             "a claim about generalization beyond the matched prompts. '!= 0?' asks whether the "
             "95% CI (t*SE) excludes zero. Reported, not gated._\n")
    pairs = {(m, p) for (m, p) in set(pq_a) | set(pq_b) if m in models}
    silent = sorted(p for (m, p) in pairs if never_activated(act_a.get((m, p)), act_b.get((m, p))))
    if pairs:
        L.append(f"**Activation:** {len(silent)} of {len(pairs)} prompt/model pairs never read the "
                 "local skill in either version, so their deltas can't come from the skill edit"
                 + (f" ({', '.join(f'`{p}`' for p in sorted(set(silent)))})." if silent else ".")
                 + " See the per-prompt table.\n")

    L.append("## Per-model summary\n")
    rows = []
    for m in models:
        a, b = mq_a.get(m, {}), mq_b.get(m, {})
        ca, cb = cost_a.get(m, {}), cost_b.get(m, {})
        rows.append([m, "A", fmt(a.get("must_coverage")), fmt(a.get("bonus_rate")),
                     fmt(a.get("avoid_violations"), 2), fmt(a.get("composite")),
                     fmt_activation(mact_a.get(m)), fmt_leaf(mact_a.get(m)),
                     fmt(ca.get("cost"), 4), fmt(ca.get("turns"), 1), a.get("n_prompts", 0)])
        rows.append([m, "B", fmt(b.get("must_coverage")), fmt(b.get("bonus_rate")),
                     fmt(b.get("avoid_violations"), 2), fmt(b.get("composite")),
                     fmt_activation(mact_b.get(m)), fmt_leaf(mact_b.get(m)),
                     fmt(cb.get("cost"), 4), fmt(cb.get("turns"), 1), b.get("n_prompts", 0)])
    L += md_table(["model", "version", "must_cov", "bonus_rate", "avoid_viol",
                   "composite", "activated", "reached leaf", "mean cost", "mean turns", "n"], rows)
    L.append("")

    L.append("## Per-prompt (must_coverage; A -> B)\n")
    rows = []
    for prompt in sorted({p for (_m, p) in pq_a} | {p for (_m, p) in pq_b}):
        for m in models:
            a, b = pq_a.get((m, prompt)), pq_b.get((m, prompt))
            if not a and not b:
                continue
            mc_a = a.get("must_coverage") if a else None
            mc_b = b.get("must_coverage") if b else None
            cp_a = a.get("composite") if a else None
            cp_b = b.get("composite") if b else None
            aa, ab = act_a.get((m, prompt)), act_b.get((m, prompt))
            note = "never activated" if never_activated(aa, ab) else ""
            rows.append([prompt, m, f"{fmt(mc_a)} -> {fmt(mc_b)}",
                         signed(delta(mc_b, mc_a)), f"{fmt(cp_a)} -> {fmt(cp_b)}",
                         f"{fmt_activation(aa)} -> {fmt_activation(ab)}",
                         f"{fmt_leaf(aa)} -> {fmt_leaf(ab)}", note])
    L += md_table(["prompt", "model", "must A->B", "delta", "composite A->B",
                   "activated A->B", "reached leaf A->B", "note"], rows)
    L.append("\n_activated: graded runs that read the local SKILL.md of that version (Skill tool "
             "or file read). web_fetch runs read the published skill from main, so they are listed "
             "apart and never count as activated; unparsed runs (signals_ok=0) are neither. "
             "reached leaf: graded runs that read the prompt's target leaf SKILL.md._\n")

    L.append("## `avoid` violations\n")
    L += avoid_lines("A", scores_a)
    L.append("")
    L += avoid_lines("B", scores_b)
    L.append("")

    L.append("## Coverage\n")
    L += coverage_lines("A", manifest_a, scores_a)
    L.append("")
    L += coverage_lines("B", manifest_b, scores_b)
    L.append("")

    L.append("## Provenance\n")
    L += provenance_lines("A", manifest_a)
    L += provenance_lines("B", manifest_b)
    L.append("")

    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description="Compare two skill-version run dirs (A vs B).")
    ap.add_argument("--a", type=Path, required=True, help="Version A run dir (has scores.csv/manifest.csv)")
    ap.add_argument("--b", type=Path, required=True, help="Version B run dir")
    ap.add_argument("--label-a", default="A", help="Human label for version A (e.g. a git ref)")
    ap.add_argument("--label-b", default="B", help="Human label for version B")
    ap.add_argument("--out", type=Path, default=None,
                    help="Output markdown path. Default: ab-scorecard.md next to --b")
    args = ap.parse_args()

    for d in (args.a, args.b):
        for name in ("scores.csv", "manifest.csv"):
            if not (d / name).exists():
                print(f"error: {d / name} not found", file=sys.stderr)
                return 2

    scores_a, scores_b = load_csv(args.a / "scores.csv"), load_csv(args.b / "scores.csv")
    manifest_a, manifest_b = load_csv(args.a / "manifest.csv"), load_csv(args.b / "manifest.csv")

    pq_a, mq_a, _, _ = aggregate_quality(scores_a)
    pq_b, mq_b, _, _ = aggregate_quality(scores_b)
    cost_a, _ = aggregate_cost(manifest_a)
    cost_b, _ = aggregate_cost(manifest_b)

    report = build_scorecard(args.a, args.b, args.label_a, args.label_b,
                              pq_a, pq_b, mq_a, mq_b, cost_a, cost_b,
                              manifest_a, manifest_b, scores_a, scores_b)

    out = args.out or (args.b / "ab-scorecard.md")
    out.write_text(report)
    print(report)
    print(f"\nwrote {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
