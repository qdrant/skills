#!/usr/bin/env bash
# Grade every valid run in a weekly dir into scores.csv (the raw grade ledger).
#
# Reads the enriched manifest (from extract-run-signals.sh — auto-run if the
# signal columns are missing), then for each run invokes the blind judge on its
# final answer. Runs excluded from scoring, with reasons surfaced:
#   - with-skill runs where the skill was not available (invalid harness state)
#   - runs with a nonzero exit_code (failed/aborted — no trustworthy answer)
#   - runs with no gradeable final answer
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

OUT_DIR=""
JUDGE_MODEL="opus"
SCORES=""
FRESH="0"

usage() {
  cat <<'USAGE'
Usage: scripts/scoring/judge-runs.sh --out-dir DIR [--judge-model M] [--scores FILE] [--fresh]

Grades every valid run under DIR into DIR/scores.csv (blind Opus judge).

By default this RESUMES: an existing scores.csv is kept and any run already graded
in it is skipped, so an interrupted judging pass can be re-run without re-grading
(and re-paying for) completed runs. Use --fresh to grade from scratch.

Options:
  --out-dir DIR       Weekly dir with manifest.csv and run subdirs.
  --judge-model M     Grader model. Default: opus
  --scores FILE       Output ledger. Default: <out-dir>/scores.csv
  --fresh             Delete any existing scores.csv and grade every run anew.
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:?}"; shift 2 ;;
    --judge-model) JUDGE_MODEL="${2:?}"; shift 2 ;;
    --scores) SCORES="${2:?}"; shift 2 ;;
    --fresh) FRESH="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n "$OUT_DIR" ]] || { echo "--out-dir is required" >&2; usage >&2; exit 64; }
MANIFEST="$OUT_DIR/manifest.csv"
[[ -f "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 66; }
[[ -z "$SCORES" ]] && SCORES="$OUT_DIR/scores.csv"

# Ensure the manifest carries the signal columns; enrich in place if not.
if ! head -1 "$MANIFEST" | grep -q 'skill_available'; then
  echo "Manifest not enriched yet; running extract-run-signals.sh ..." >&2
  "$SCRIPT_DIR/extract-run-signals.sh" --out-dir "$OUT_DIR" >&2
fi

# Column indices (1-based) in the enriched manifest.
col() { head -1 "$MANIFEST" | tr ',' '\n' | grep -nx "$1" | cut -d: -f1; }
C_PROMPT=$(col prompt); C_FAMILY=$(col skill_family); C_MODEL=$(col model)
C_COND=$(col condition); C_REP=$(col rep); C_RUNID=$(col run_id)
C_EXIT=$(col exit_code); C_AVAIL=$(col skill_available); C_BUDGET=$(col budget_hit)

# Fresh start deletes the ledger; otherwise resume (keep it, skip graded runs).
[[ "$FRESH" == "1" ]] && rm -f "$SCORES"

# A run counts as already graded if a scores.csv row matches its
# (prompt, model, condition, rep) exactly. Exact field compare (quoting-safe).
already_graded() {
  [[ -f "$SCORES" ]] || return 1
  awk -F, -v p="$1" -v m="$2" -v c="$3" -v r="$4" \
    'NR>1 && $1==p && $3==m && $4==c && $5==r {found=1; exit} END{exit !found}' "$SCORES"
}

graded=0; skip_invalid=0; skip_error=0; skip_noanswer=0

tail -n +2 "$MANIFEST" | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  get() { printf '%s' "$line" | cut -d, -f"$1"; }
  prompt=$(get "$C_PROMPT"); family=$(get "$C_FAMILY"); model=$(get "$C_MODEL")
  cond=$(get "$C_COND"); rep=$(get "$C_REP"); run_id=$(get "$C_RUNID")
  exit_code=$(get "$C_EXIT"); avail=$(get "$C_AVAIL")
  run_dir="$OUT_DIR/$run_id"

  if already_graded "$prompt" "$model" "$cond" "$rep"; then
    echo "  skip (already graded) $model/$cond/rep$rep $prompt" >&2; continue
  fi

  budget=""; [[ -n "${C_BUDGET:-}" ]] && budget=$(get "$C_BUDGET")
  if [[ "$budget" == "1" ]]; then
    echo "  skip (budget-capped: truncated) $run_id" >&2; skip_error=$((skip_error+1)); continue
  fi
  if [[ "$cond" == "with-skill" && "$avail" != "1" ]]; then
    echo "  skip (invalid: skill unavailable) $run_id" >&2; skip_invalid=$((skip_invalid+1)); continue
  fi
  if [[ "$exit_code" != "0" ]]; then
    echo "  skip (exit=$exit_code) $run_id" >&2; skip_error=$((skip_error+1)); continue
  fi
  if [[ ! -f "$run_dir/test-prompt.json" ]]; then
    echo "  skip (no test-prompt.json) $run_id" >&2; skip_noanswer=$((skip_noanswer+1)); continue
  fi

  echo "  judging $model/$cond/rep$rep  $prompt" >&2
  if python3 "$SCRIPT_DIR/judge.py" "$run_dir" \
      --judge-model "$JUDGE_MODEL" \
      --skill "$family" --condition "$cond" --rep "$rep" --model-label "$model" \
      --out "$SCORES" >&2; then
    graded=$((graded+1))
  else
    echo "  !! judge failed on $run_id" >&2; skip_noanswer=$((skip_noanswer+1))
  fi
done

# The while loop runs in a subshell (pipe), so recompute the tallies for the summary.
echo
echo "Scores ledger: $SCORES"
if [[ -f "$SCORES" ]]; then
  n_rows=$(( $(wc -l < "$SCORES") - 1 ))
  n_runs=$(tail -n +2 "$SCORES" | cut -d, -f1,3,4,5 | sort -u | wc -l | tr -d ' ')
  echo "Graded $n_rows rubric items across $n_runs runs."
else
  echo "No runs graded." >&2
fi