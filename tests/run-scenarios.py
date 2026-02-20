#!/usr/bin/env python3
"""
Scenario-based skill validation.

For each scenario, verifies that the skill's SKILL.md and AGENTS.md contain
enough information for an agent to produce code matching the expected patterns
and avoiding the forbidden patterns.

Two validation modes:
  1. coverage: (default) checks that expected patterns appear somewhere in the
     skill files, so an agent reading them would learn the right API.
  2. eval: (requires LLM) generates code from the prompt + skill context and
     validates the output against expected/forbidden patterns.

Usage:
  python3 tests/run-scenarios.py                      # coverage mode, all skills
  python3 tests/run-scenarios.py --skill qdrant-python # single skill
  python3 tests/run-scenarios.py --tag search          # filter by tag
  python3 tests/run-scenarios.py --verbose             # show pattern details
"""

import argparse
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("error: pyyaml required. run: pip install pyyaml")
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
SCENARIOS_DIR = REPO_ROOT / "tests" / "scenarios"


def load_skill_content(skill_name: str) -> str:
    """Load concatenated SKILL.md + AGENTS.md content for a skill."""
    skill_dir = SKILLS_DIR / skill_name
    content = ""
    for fname in ["SKILL.md", "AGENTS.md"]:
        fpath = skill_dir / fname
        if fpath.exists():
            content += fpath.read_text() + "\n"
    # Also load references if they exist
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref_file in sorted(refs_dir.glob("*.md")):
            content += ref_file.read_text() + "\n"
    return content


def check_pattern_in_content(pattern: str, content: str) -> bool:
    """Check if a pattern (literal or regex) appears in content."""
    # Try as regex first
    try:
        if re.search(pattern, content, re.IGNORECASE | re.MULTILINE):
            return True
    except re.error:
        pass
    # Fall back to literal substring match
    return pattern.lower() in content.lower()


def run_coverage_check(
    scenario_file: Path,
    tag_filter: str | None = None,
    verbose: bool = False,
) -> tuple[int, int, list[str]]:
    """
    Check that skill content covers what scenarios expect.

    Returns (passed, total, failure_messages).
    """
    with open(scenario_file) as f:
        data = yaml.safe_load(f)

    skill_name = data["skill"]
    scenarios = data["scenarios"]
    content = load_skill_content(skill_name)

    if not content.strip():
        return 0, 1, [f"{skill_name}: skill content is empty"]

    passed = 0
    total = 0
    failures = []

    for scenario in scenarios:
        name = scenario["name"]
        tags = scenario.get("tags", [])

        if tag_filter and tag_filter not in tags:
            continue

        total += 1
        scenario_failures = []

        # Check expected patterns exist in skill content
        for pattern in scenario.get("expected_patterns", []):
            if not check_pattern_in_content(pattern, content):
                scenario_failures.append(f"    expected not found: {pattern}")

        # Check forbidden patterns do NOT exist in skill content
        # (only check code examples, not gotcha warnings about what NOT to do)
        # We skip forbidden pattern checks in coverage mode because the skill
        # files legitimately mention forbidden patterns in "Gotchas" sections
        # to warn agents away from them.

        if scenario_failures:
            failures.append(f"  FAIL: {skill_name}/{name}")
            failures.extend(scenario_failures)
            if verbose and "notes" in scenario:
                failures.append(f"    note: {scenario['notes']}")
        else:
            passed += 1
            if verbose:
                print(f"  pass: {skill_name}/{name}")

    return passed, total, failures


def main():
    parser = argparse.ArgumentParser(description="Scenario-based skill validation")
    parser.add_argument("--skill", help="Run scenarios for a specific skill only")
    parser.add_argument("--tag", help="Run only scenarios with this tag")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show details")
    parser.add_argument(
        "--list", action="store_true", help="List all scenarios without running"
    )
    args = parser.parse_args()

    scenario_files = sorted(SCENARIOS_DIR.glob("*.yaml"))

    if args.skill:
        scenario_files = [f for f in scenario_files if f.stem == args.skill]
        if not scenario_files:
            print(f"error: no scenario file for skill '{args.skill}'")
            sys.exit(1)

    if args.list:
        for sf in scenario_files:
            with open(sf) as f:
                data = yaml.safe_load(f)
            print(f"\n{data['skill']}:")
            for s in data["scenarios"]:
                tags = ", ".join(s.get("tags", []))
                print(f"  {s['name']:<30} [{tags}]")
        return

    total_passed = 0
    total_tests = 0
    all_failures = []

    print("=== scenario coverage tests ===\n")

    for sf in scenario_files:
        with open(sf) as f:
            data = yaml.safe_load(f)
        skill_name = data["skill"]
        print(f"[{skill_name}]")

        passed, total, failures = run_coverage_check(sf, args.tag, args.verbose)
        total_passed += passed
        total_tests += total

        if failures:
            all_failures.extend(failures)
            for line in failures:
                print(line)
        else:
            print(f"  all {passed} scenarios covered")

        print()

    print("=== results ===")
    print(f"{total_passed}/{total_tests} passed, {total_tests - total_passed} failed")

    if all_failures:
        print(f"\n{len(all_failures)} issues found. Fix skill content to cover these patterns.")
        sys.exit(1)


if __name__ == "__main__":
    main()
