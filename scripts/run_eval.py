#!/usr/bin/env python3
"""Run skill evals using claude -p and grade responses."""

import json
import subprocess
import sys
import re
from pathlib import Path

# skill -> list of skill files to read
SKILL_MAP = {
    1: [
        "skills/qdrant-scaling/SKILL.md",
        "skills/qdrant-scaling/minimize-latency/SKILL.md",
        "skills/qdrant-scaling/scaling-data-volume/vertical-scaling/SKILL.md",
        "skills/qdrant-scaling/scaling-data-volume/horizontal-scaling/SKILL.md",
    ],
    2: [
        "skills/qdrant-scaling/SKILL.md",
        "skills/qdrant-scaling/scaling-data-volume/tenant-scaling/SKILL.md",
    ],
    3: [
        "skills/qdrant-scaling/SKILL.md",
        "skills/qdrant-scaling/scaling-data-volume/sliding-time-window/SKILL.md",
    ],
    4: [
        "skills/qdrant-scaling/SKILL.md",
        "skills/qdrant-scaling/scaling-data-volume/horizontal-scaling/SKILL.md",
    ],
    5: [
        "skills/qdrant-version-upgrade/SKILL.md",
    ],
    6: [
        "skills/qdrant-scaling/SKILL.md",
        "skills/qdrant-scaling/scaling-qps/SKILL.md",
    ],
}


def load_skill_context(eval_id: int, repo_root: Path) -> str:
    files = SKILL_MAP.get(eval_id, [])
    parts = []
    for f in files:
        path = repo_root / f
        if path.exists():
            parts.append(f"--- {f} ---\n{path.read_text()}")
    return "\n\n".join(parts)


def run_claude(prompt: str) -> str:
    result = subprocess.run(
        ["claude", "-p", "--output-format", "text"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        print(f"  claude -p failed: {result.stderr[:200]}", file=sys.stderr)
        return ""
    return result.stdout


def grade_response(response: str, expectations: list[str]) -> list[dict]:
    numbered = "\n".join(f"{i+1}. {e}" for i, e in enumerate(expectations))
    grade_prompt = f"""Grade this response against each numbered assertion. For each, output exactly one line in this format:
<number>|PASS|<brief evidence>
or
<number>|FAIL|<brief reason>

Response to grade:
{response}

Assertions:
{numbered}

Output only the numbered PASS/FAIL lines, nothing else."""

    output = run_claude(grade_prompt)
    results = []
    # parse by assertion number
    graded = {}
    for line in output.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        parts = line.split("|", 2)
        if len(parts) >= 2:
            try:
                idx = int(parts[0].strip().rstrip("."))
                verdict = parts[1].strip().upper()
                evidence = parts[2].strip() if len(parts) > 2 else ""
                graded[idx] = (verdict == "PASS", evidence)
            except (ValueError, IndexError):
                continue
    for i, exp in enumerate(expectations):
        if (i + 1) in graded:
            passed, evidence = graded[i + 1]
        else:
            passed, evidence = False, "no grading output for this assertion"
        results.append({"text": exp, "passed": passed, "evidence": evidence})
    return results


def main():
    repo_root = Path(__file__).parent.parent
    evals_path = repo_root / "evals" / "evals.json"

    if not evals_path.exists():
        print("error: evals/evals.json not found")
        sys.exit(1)

    evals = json.loads(evals_path.read_text())

    total_passed = 0
    total_assertions = 0
    results = []

    for ev in evals["evals"]:
        eval_id = ev["id"]
        prompt = ev["prompt"]
        expectations = ev["expectations"]

        print(f"\n=== eval {eval_id}: {prompt[:60]}... ===")

        # run with skill context
        skill_context = load_skill_context(eval_id, repo_root)
        full_prompt = f"""You have access to the following Qdrant skill knowledge:

{skill_context}

Using this knowledge, answer the following question. Be specific with config recommendations and include doc links where the skill provides them.

User question: {prompt}"""

        print("  running claude with skill...")
        response = run_claude(full_prompt)

        if not response:
            print("  ERROR: no response from claude")
            for exp in expectations:
                results.append({"eval_id": eval_id, "text": exp, "passed": False, "evidence": "no response"})
            total_assertions += len(expectations)
            continue

        print("  grading...")
        grades = grade_response(response, expectations)

        passed = sum(1 for g in grades if g["passed"])
        total = len(grades)
        total_passed += passed
        total_assertions += total

        for g in grades:
            status = "PASS" if g["passed"] else "FAIL"
            print(f"  {status}: {g['text']}")
            results.append({"eval_id": eval_id, **g})

        print(f"  score: {passed}/{total}")

    print(f"\n{'='*50}")
    print(f"TOTAL: {total_passed}/{total_assertions} ({total_passed/total_assertions*100:.0f}%)")

    # write results
    output_path = repo_root / "eval-results.json"
    output_path.write_text(json.dumps({
        "total_passed": total_passed,
        "total_assertions": total_assertions,
        "pass_rate": total_passed / total_assertions if total_assertions > 0 else 0,
        "results": results,
    }, indent=2))
    print(f"results written to {output_path}")

    # fail if pass rate drops below 80%
    pass_rate = total_passed / total_assertions if total_assertions > 0 else 0
    if pass_rate < 0.8:
        print(f"\nFAIL: pass rate {pass_rate:.0%} below 80% threshold")
        sys.exit(1)
    else:
        print(f"\nPASS: {pass_rate:.0%} pass rate")


if __name__ == "__main__":
    main()
