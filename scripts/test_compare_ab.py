"""Tests for the activation columns in scripts/scoring/compare-ab.py."""
import contextlib
import csv
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

_PATH = Path(__file__).resolve().parent / "scoring" / "compare-ab.py"
_SPEC = importlib.util.spec_from_file_location("compare_ab", _PATH)
compare_ab = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(compare_ab)

MANIFEST_FIELDS = ["prompt", "model", "rep", "run_id", "exit_code", "skill_available",
                   "skill_activation", "reached_leaf", "signals_ok", "budget_hit",
                   "total_cost_usd", "num_turns", "skills_sha", "cli_version"]
SCORE_FIELDS = ["prompt", "model", "rep", "item_type", "item_text", "verdict", "credit",
                "evidence_quote", "contested"]


def run(prompt, rep, activation, leaf="0", signals_ok="1"):
    return {"prompt": prompt, "model": "sonnet", "rep": str(rep), "run_id": f"{prompt}-{rep}",
            "exit_code": "0", "skill_available": "1", "skill_activation": activation,
            "reached_leaf": leaf, "signals_ok": signals_ok, "budget_hit": "0",
            "total_cost_usd": "0.10", "num_turns": "3", "skills_sha": "abc", "cli_version": "1"}


def score(prompt, rep, credit="1"):
    return {"prompt": prompt, "model": "sonnet", "rep": str(rep), "item_type": "must",
            "item_text": "x", "verdict": "met" if credit == "1" else "not_met",
            "credit": credit, "evidence_quote": "", "contested": ""}


class ActivationCounts(unittest.TestCase):
    def test_counts_only_graded_runs_and_splits_web_fetch(self):
        manifest = [
            run("p", 1, "skill_tool", leaf="1"),
            run("p", 2, "file_read"),
            run("p", 3, "web_fetch"),
            run("p", 4, "none"),
            run("p", 5, "skill_tool", signals_ok="0"),
            run("p", 6, "skill_tool"),  # not graded: no score rows
        ]
        scores = [score("p", r) for r in (1, 2, 3, 4, 5)]
        c = compare_ab.activation_by_prompt(manifest, scores)[("sonnet", "p")]
        self.assertEqual(c, {"n": 5, "activated": 2, "leaf": 1, "web_fetch": 1, "unknown": 1})
        self.assertEqual(compare_ab.fmt_activation(c), "2/5 (1 web_fetch, 1 unparsed)")
        self.assertEqual(compare_ab.fmt_leaf(c), "1/5")

    def test_missing_signals_ok_column_counts_as_parsed(self):
        row = run("p", 1, "file_read")
        del row["signals_ok"]
        c = compare_ab.activation_by_prompt([row], [score("p", 1)])[("sonnet", "p")]
        self.assertEqual(c["activated"], 1)

    def test_never_activated(self):
        none = {"n": 2, "activated": 0, "leaf": 0, "web_fetch": 1, "unknown": 0}
        some = {"n": 2, "activated": 1, "leaf": 1, "web_fetch": 0, "unknown": 0}
        unparsed = {"n": 2, "activated": 0, "leaf": 0, "web_fetch": 0, "unknown": 2}
        self.assertTrue(compare_ab.never_activated(none, none))
        self.assertFalse(compare_ab.never_activated(none, some))
        # All-unparsed runs are unknown, not a trigger miss.
        self.assertFalse(compare_ab.never_activated(unparsed, unparsed))
        self.assertFalse(compare_ab.never_activated(None, None))

    def test_empty_cell(self):
        self.assertEqual(compare_ab.fmt_activation(None), "n/a")
        self.assertEqual(compare_ab.fmt_leaf({"n": 0}), "n/a")


class Scorecard(unittest.TestCase):
    def _write(self, d, manifest, scores):
        d.mkdir()
        for name, fields, rows in (("manifest.csv", MANIFEST_FIELDS, manifest),
                                   ("scores.csv", SCORE_FIELDS, scores)):
            with (d / name).open("w", newline="") as f:
                w = csv.DictWriter(f, fieldnames=fields)
                w.writeheader()
                w.writerows(rows)

    def test_scorecard_shows_activation_columns_and_flag(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / "a", Path(tmp) / "b"
            self._write(a, [run("hit", 1, "none"), run("hit", 2, "none"),
                            run("miss", 1, "none"), run("miss", 2, "web_fetch")],
                        [score(p, r) for p in ("hit", "miss") for r in (1, 2)])
            self._write(b, [run("hit", 1, "skill_tool", leaf="1"), run("hit", 2, "file_read"),
                            run("miss", 1, "none"), run("miss", 2, "none")],
                        [score(p, r) for p in ("hit", "miss") for r in (1, 2)])
            out = Path(tmp) / "card.md"
            argv, sys.argv = sys.argv, ["compare-ab.py", "--a", str(a), "--b", str(b),
                                        "--out", str(out)]
            try:
                with contextlib.redirect_stdout(io.StringIO()), \
                        contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(compare_ab.main(), 0)
            finally:
                sys.argv = argv
            card = out.read_text()
        self.assertIn("activated A->B", card)
        self.assertIn("reached leaf A->B", card)
        self.assertIn("0/2 -> 2/2", card)
        self.assertIn("0/2 -> 1/2", card)
        self.assertIn("0/2 (1 web_fetch) -> 0/2", card)
        self.assertIn("1 of 2 prompt/model pairs never read the local skill", card)
        self.assertIn("(`miss`)", card)
        miss_row = next(l for l in card.splitlines() if l.startswith("| miss"))
        self.assertIn("never activated", miss_row)
        hit_row = next(l for l in card.splitlines() if l.startswith("| hit"))
        self.assertNotIn("never activated", hit_row)
        # Per-model summary: A 0/4, B 2/4.
        self.assertIn("0/4 (1 web_fetch)", card)
        self.assertIn("2/4", card)


if __name__ == "__main__":
    unittest.main()
