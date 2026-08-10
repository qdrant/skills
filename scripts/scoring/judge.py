#!/usr/bin/env python3
"""Blind LLM judge for the weekly skill scoring framework.

Grades one run's *final answer only* against its rubric, one verdict per item,
under the three SCORING.md rules:

  1. Blind          - the judge sees only prompt, final answer, and rubric.
                      Model name and skill/no-skill condition are never included.
  2. Final answer   - grade the last assistant message (the deliverable), not the
                      transcript's thinking/tool noise.
  3. Evidence       - every `met`/`violated` verdict must quote a span from the
                      answer; requiring a quote curbs hallucinated "yes" grades.

Per-type verdict vocabulary and credit (SCORING.md "Per-Item Credit"):

    must   met | missing        met=1.0 missing=0.0   contribution = +credit
    bonus  met | absent         met=1.0 absent=0.0    contribution = +credit
    avoid  violated | clean     viol=1.0 clean=0.0     contribution = -credit

`avoid` polarity is inverted: credit 1.0 means the answer did the bad thing, so
its contribution is negative. The composite weights (0.10 bonus, 0.25 avoid) are
applied later by the summarizer, not here -- this stays the raw signed ledger.

The model call is a pluggable backend so the scoring logic is testable without an
API call. Backends:
  - claude CLI (default): `claude -p --model <m> --output-format json`
  - canned: read a pre-captured judge JSON (offline tests / replays)
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

# --- verdict / credit model -------------------------------------------------

# type -> (positive_verdict, negative_verdict, contribution_sign)
VERDICTS = {
    "must": ("met", "missing", +1.0),
    "bonus": ("met", "absent", +1.0),
    "avoid": ("violated", "clean", -1.0),
}


def score_item(item_type: str, verdict: str) -> tuple[float, float, bool]:
    """Return (credit, contribution, valid). credit is always the raw 0/1;
    contribution carries polarity so cross-type sums stay sane."""
    spec = VERDICTS.get(item_type)
    if spec is None:
        return 0.0, 0.0, False
    positive, negative, sign = spec
    if verdict == positive:
        return 1.0, 1.0 * sign, True
    if verdict == negative:
        return 0.0, 0.0, True
    return 0.0, 0.0, False  # unrecognized verdict for this type


# --- final-answer extraction ------------------------------------------------


def extract_final_answer(run_dir: Path) -> str:
    """Pull the final assistant message from a stream-json stdout.txt.

    Prefers the terminal `result` event's `.result` (the CLI's canonical final
    answer). Falls back to the last assistant text block if that is missing or
    empty (some early/aborted runs emit an empty result)."""
    stdout = run_dir / "stdout.txt"
    if not stdout.exists():
        raise FileNotFoundError(f"no stdout.txt in {run_dir}")

    result_text = ""
    last_assistant = ""
    for line in stdout.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(ev, dict):
            continue
        if ev.get("type") == "result" and isinstance(ev.get("result"), str):
            result_text = ev["result"]
        elif ev.get("type") == "assistant":
            msg = ev.get("message", {})
            for block in msg.get("content", []) or []:
                if isinstance(block, dict) and block.get("type") == "text":
                    last_assistant = block.get("text", "") or last_assistant
    answer = result_text.strip() or last_assistant.strip()
    return answer


# --- grading prompt ---------------------------------------------------------

GRADING_PREAMBLE = """\
You are a strict, blind grader for answers to a technical question about the \
Qdrant vector database. You are given the user's PROMPT, a candidate ANSWER, \
and a RUBRIC. Grade each rubric item independently and return JSON only.

Rules:
- Judge ONLY the ANSWER text below. Do not use outside knowledge to fill gaps \
the answer leaves; if the answer does not say it, it is not there.
- For every "met" or "violated" verdict you MUST quote the exact span from the \
ANSWER that supports it, verbatim, in the "evidence" field. If you cannot quote \
it, it is not met. Keep each quote short — at most ~15 words; a phrase is enough.
- Grade each item by its type:
  * "must": verdict "met" if the ANSWER clearly satisfies the item, else \
"missing". Binary — no partial credit.
  * "bonus": verdict "met" if present, else "absent".
  * "avoid": this is a bad behavior. Actively hunt for it. verdict "violated" \
only if you can quote the answer doing it; otherwise "clean". When genuinely \
unsure, prefer "clean" — but do not overlook a clear violation.

Return a single JSON object, no prose, no code fences:
{"verdicts": [{"index": <1-based item number>, "verdict": "<verdict>", \
"evidence": "<verbatim quote from the answer, or empty for missing/absent/clean>"}]}
Return exactly one verdict object per rubric item, in order."""


def render_prompt(prompt: str, answer: str, rubric: list[dict]) -> str:
    rubric_lines = []
    for i, item in enumerate(rubric, 1):
        rubric_lines.append(f'{i}. [{item["type"]}] {item["text"]}')
    return (
        f"{GRADING_PREAMBLE}\n\n"
        f"PROMPT:\n{prompt.strip()}\n\n"
        f"ANSWER:\n<<<ANSWER\n{answer.strip()}\nANSWER\n\n"
        f"RUBRIC:\n" + "\n".join(rubric_lines) + "\n"
    )


# --- judge-output parsing ---------------------------------------------------


def _extract_json_object(text: str) -> Optional[dict]:
    """Best-effort: find the first {...} JSON object in text, tolerating code
    fences or stray prose around it."""
    text = text.strip()
    # Strip a leading ```json / ``` fence if present.
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        if text.rstrip().endswith("```"):
            text = text.rstrip()[:-3]
    # Try direct parse first.
    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return obj
        if isinstance(obj, list):
            return {"verdicts": obj}
    except json.JSONDecodeError:
        pass
    # Fall back to slicing between the outermost braces.
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end > start:
        try:
            obj = json.loads(text[start : end + 1])
            if isinstance(obj, dict):
                return obj
        except json.JSONDecodeError:
            return None
    return None


def _salvage_verdicts(text: str) -> dict[int, dict]:
    """Scan text for individual well-formed {..."index"...} objects using
    incremental JSON decoding. Robust to a truncated tail (the last, incomplete
    object is skipped while every complete one before it is kept) and to prose or
    code fences around the JSON."""
    dec = json.JSONDecoder()
    out: dict[int, dict] = {}
    i, n = 0, len(text)
    while i < n:
        if text[i] == "{":
            try:
                obj, end = dec.raw_decode(text, i)
            except json.JSONDecodeError:
                i += 1
                continue
            if isinstance(obj, dict) and isinstance(obj.get("index"), int) and "verdict" in obj:
                out[obj["index"]] = obj
            i = end
            continue
        i += 1
    return out


def parse_verdicts(judge_text: str, rubric: list[dict]) -> list[dict]:
    """Align the judge's verdicts to the rubric by 1-based index. Missing or
    unparseable items are marked verdict '' (invalid) so nothing is silently
    scored as passing."""
    obj = _extract_json_object(judge_text) or {}
    raw = obj.get("verdicts", []) if isinstance(obj, dict) else []
    by_index: dict[int, dict] = {}
    for v in raw:
        if isinstance(v, dict) and isinstance(v.get("index"), int):
            by_index[v["index"]] = v
    # If the whole-object parse came up short (e.g. truncated tail, fenced, or
    # prose-wrapped), salvage any individual verdict objects it missed.
    if len(by_index) < len(rubric):
        for idx, v in _salvage_verdicts(judge_text).items():
            by_index.setdefault(idx, v)

    rows = []
    for i, item in enumerate(rubric, 1):
        v = by_index.get(i, {})
        verdict = (v.get("verdict") or "").strip().lower()
        evidence = (v.get("evidence") or "").strip()
        credit, contribution, valid = score_item(item["type"], verdict)
        rows.append(
            {
                "item_type": item["type"],
                "item_text": item["text"],
                "verdict": verdict if valid else (verdict or "PARSE_ERROR"),
                "credit": credit,
                "contribution": contribution,
                "valid": valid,
                "evidence_quote": evidence,
            }
        )
    return rows


# --- backends ---------------------------------------------------------------

JudgeFn = Callable[[str], str]


def load_env_key(repo_root: Path) -> None:
    """Populate ANTHROPIC_API_KEY from .env if not already in the environment."""
    if os.environ.get("ANTHROPIC_API_KEY"):
        return
    env = repo_root / ".env"
    if not env.exists():
        return
    for line in env.read_text().splitlines():
        line = line.strip()
        if line.startswith("ANTHROPIC_API_KEY="):
            val = line.split("=", 1)[1].strip().strip("'\"")
            if val:
                os.environ["ANTHROPIC_API_KEY"] = val
            return


def claude_cli_backend(model: str, repo_root: Path, cost_sink: list | None = None) -> JudgeFn:
    load_env_key(repo_root)

    def run(prompt: str) -> str:
        proc = subprocess.run(
            [
                "claude", "-p",
                "--model", model,
                "--output-format", "json",
                "--max-turns", "1",
                "--permission-mode", "dontAsk",
            ],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=180,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"claude judge failed: {proc.stderr[:300]}")
        # The CLI's json envelope carries the assistant text in `.result` and the
        # grading call's own dollar cost in `.total_cost_usd` — record the latter
        # so the scorecard can report judge spend (otherwise silently discarded).
        try:
            env = json.loads(proc.stdout)
        except json.JSONDecodeError:
            return proc.stdout
        if not isinstance(env, dict):
            return proc.stdout
        if cost_sink is not None:
            try:
                cost_sink.append(float(env.get("total_cost_usd") or 0.0))
            except (TypeError, ValueError):
                pass
        return env.get("result", "")

    return run


def canned_backend(path: Path) -> JudgeFn:
    text = path.read_text()
    return lambda _prompt: text


# --- grading one run --------------------------------------------------------


@dataclass
class RunMeta:
    prompt_name: str
    skill: str
    model: str
    condition: str
    rep: str


def grade_run(run_dir: Path, backend: JudgeFn, meta: RunMeta) -> list[dict]:
    tp_path = run_dir / "test-prompt.json"
    if not tp_path.exists():
        raise FileNotFoundError(f"no test-prompt.json in {run_dir}")
    tp = json.loads(tp_path.read_text())
    prompt = tp["prompt"]
    rubric = tp["rubric"]

    answer = extract_final_answer(run_dir)
    if not answer:
        raise ValueError(f"empty final answer in {run_dir} — cannot grade")

    judge_text = backend(render_prompt(prompt, answer, rubric))
    verdicts = parse_verdicts(judge_text, rubric)

    rows = []
    for item in verdicts:
        rows.append(
            {
                "prompt": meta.prompt_name,
                "skill": meta.skill,
                "model": meta.model,
                "condition": meta.condition,
                "rep": meta.rep,
                "contested": "",  # reserved for multi-sample voting
                **item,
            }
        )
    return rows


CSV_COLUMNS = [
    "prompt", "skill", "model", "condition", "rep",
    "item_type", "item_text", "verdict", "credit", "contribution",
    "contested", "evidence_quote",
]


def rows_to_csv(rows: list[dict]) -> str:
    import csv
    import io

    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=CSV_COLUMNS, extrasaction="ignore")
    w.writeheader()
    for r in rows:
        w.writerow(r)
    return buf.getvalue()


# --- calibration ------------------------------------------------------------


def calibrate(run_dir: Path, backend: JudgeFn, meta: RunMeta, repeat: int) -> None:
    """Grade the same run `repeat` times and report per-item verdict agreement —
    SCORING.md's judge self-agreement check. High agreement (esp. on binary
    musts) means one vote stands; noisy items are flagged for a second sample."""
    tp = json.loads((run_dir / "test-prompt.json").read_text())
    rubric = tp["rubric"]
    prompt = tp["prompt"]
    answer = extract_final_answer(run_dir)

    samples = []
    for k in range(repeat):
        verdicts = parse_verdicts(backend(render_prompt(prompt, answer, rubric)), rubric)
        samples.append([v["verdict"] for v in verdicts])
        print(f"  sample {k + 1}/{repeat} graded", file=sys.stderr)

    print(f"\nSelf-agreement over {repeat} samples ({run_dir.name}):\n")
    print(f"{'#':>2}  {'type':<6} {'agree':<7} verdicts")
    n_unanimous = 0
    must_unanimous = 0
    n_must = 0
    for i, item in enumerate(rubric):
        col = [s[i] for s in samples]
        unanimous = len(set(col)) == 1
        n_unanimous += unanimous
        if item["type"] == "must":
            n_must += 1
            must_unanimous += unanimous
        mark = "UNANIM" if unanimous else "SPLIT"
        print(f"{i + 1:>2}  {item['type']:<6} {mark:<7} {col}")
    print(
        f"\nunanimous items: {n_unanimous}/{len(rubric)}"
        f"  |  unanimous musts: {must_unanimous}/{n_must}"
    )


# --- CLI --------------------------------------------------------------------


def infer_meta(run_dir: Path, args) -> RunMeta:
    model = args.model_label or ""
    if not model:
        md = run_dir / "metadata.json"
        if md.exists():
            model = json.loads(md.read_text()).get("model", "") or ""
    # skill defaults to the test-prompt name (one prompt per skill); the matrix
    # runner can pass the resolved family explicitly via --skill.
    tp = run_dir / "test-prompt.json"
    name = ""
    if tp.exists():
        name = json.loads(tp.read_text()).get("name", "") or run_dir.name
    return RunMeta(
        prompt_name=name or run_dir.name,
        skill=args.skill or name or run_dir.name,
        model=model or "unknown",
        condition=args.condition,
        rep=args.rep,
    )


def main() -> int:
    p = argparse.ArgumentParser(description="Blind LLM judge for one run.")
    p.add_argument("run_dir", type=Path, help="runs/<id>/ with test-prompt.json + stdout.txt")
    p.add_argument("--judge-model", default="opus", help="grader model (default: opus)")
    p.add_argument("--canned", type=Path, help="read judge output from a file instead of calling the model")
    p.add_argument("--repeat", type=int, default=0, help="calibration: grade N times and report self-agreement")
    p.add_argument("--skill", default="", help="skill/family label for the CSV (default: prompt name)")
    p.add_argument("--condition", default="NA", help="no-skill | with-skill (for the CSV)")
    p.add_argument("--rep", default="NA", help="generation rep index (for the CSV)")
    p.add_argument("--model-label", default="", help="generation model label for the CSV (default: metadata.json)")
    p.add_argument("--out", type=Path, help="append CSV rows here (writes header if new); default stdout")
    args = p.parse_args()

    run_dir = args.run_dir
    if not (run_dir / "test-prompt.json").exists():
        print(f"error: {run_dir} has no test-prompt.json (not a scored run)", file=sys.stderr)
        return 2

    repo_root = Path(__file__).resolve().parents[2]
    cost_sink: list = []
    if args.canned:
        backend = canned_backend(args.canned)
    else:
        backend = claude_cli_backend(args.judge_model, repo_root, cost_sink)

    meta = infer_meta(run_dir, args)

    if args.repeat and args.repeat > 1:
        calibrate(run_dir, backend, meta, args.repeat)
        return 0

    rows = grade_run(run_dir, backend, meta)

    # Record this run's judge (Opus) spend next to its transcript so the
    # summarizer can total judge cost across the week.
    if cost_sink:
        (run_dir / "judge_cost.txt").write_text(f"{sum(cost_sink):.6f}\n")

    invalid = [r for r in rows if not r["valid"]]
    if invalid:
        print(f"warning: {len(invalid)} item(s) failed to parse a valid verdict", file=sys.stderr)

    csv_text = rows_to_csv(rows)
    if args.out:
        new = not args.out.exists()
        with args.out.open("a") as f:
            f.write(csv_text if new else csv_text.split("\n", 1)[1])
        print(f"wrote {len(rows)} rows -> {args.out}", file=sys.stderr)
    else:
        sys.stdout.write(csv_text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
