#!/usr/bin/env bash
# Enrich a weekly manifest with the per-run signals derived from each captured
# transcript, producing the manifest.csv schema SCORING.md describes.
#
# Reads the base manifest written by run-eval-matrix.sh (first 10 columns) and,
# for each run's stdout.txt (stream-json), adds:
#
#   skill_available   1 if the run's init skill list contains the mapped family.
#                     For with-skill runs, 0 is a hard harness failure (the run
#                     is invalid and excluded downstream). For no-skill runs it
#                     is expected 0 and just recorded.
#   skill_activation  how the model reached the skill, by priority:
#                       skill_tool  invoked the Skill tool for the family
#                       file_read   read an installed family SKILL.md
#                       web_fetch   pulled skills.qdrant.tech instead
#                       none        never reached it (a trigger miss, not a bug)
#   reached_leaf      1 if it read the prompt's specific target leaf SKILL.md
#                     (progressive disclosure actually fired), else 0.
#   fetched_site      1 if it fetched skills.qdrant.tech at all.
#   fetched_count     number of skills.qdrant.tech fetches (WebFetch or curl).
#   model_snapshot    the exact model string from init (e.g. claude-haiku-...).
#   cli_version       claude_code_version from init.
#
# Idempotent: re-reads only the 10 base columns, so it can be run repeatedly.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OUT_DIR=""
MANIFEST=""

usage() {
  cat <<'USAGE'
Usage: scripts/scoring/extract-run-signals.sh --out-dir DIR [--manifest FILE]

Enriches DIR/manifest.csv in place with per-run signals from the transcripts
under DIR. Run after run-eval-matrix.sh.

Options:
  --out-dir DIR    Weekly dir containing manifest.csv and the run subdirs.
  --manifest FILE  Manifest path (default: <out-dir>/manifest.csv).
  -h, --help       Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:?}"; shift 2 ;;
    --manifest) MANIFEST="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n "$OUT_DIR" ]] || { echo "--out-dir is required" >&2; usage >&2; exit 64; }
[[ -z "$MANIFEST" ]] && MANIFEST="$OUT_DIR/manifest.csv"
[[ -f "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 66; }

OUT_HEADER="prompt,skill_family,skill_leaf,model,condition,rep,run_id,exit_code,skills_sha,timestamp,skill_available,skill_activation,reached_leaf,fetched_site,fetched_count,model_snapshot,cli_version,total_cost_usd,num_turns,result_subtype,budget_hit,signals_ok,duration_ms"

tmp="$(mktemp)"
echo "$OUT_HEADER" > "$tmp"

tail -n +2 "$MANIFEST" | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  base="$(printf '%s' "$line" | cut -d, -f1-10)"
  IFS=, read -r prompt family leaf model condition rep run_id exit_code skills_sha timestamp <<< "$base"

  stdout="$OUT_DIR/$run_id/stdout.txt"

  skill_available=0
  activation="none"
  reached_leaf=0
  fetched_site=0
  fetched_count=0
  model_snapshot=""
  cli_version=""
  total_cost_usd=""
  num_turns=""
  result_subtype=""
  budget_hit=0
  signals_ok=1
  duration_ms=""

  if [[ -f "$stdout" ]]; then
    init="$(grep -m1 '"subtype":"init"' "$stdout" || true)"
    if [[ -n "$init" ]]; then
      model_snapshot="$(printf '%s' "$init" | jq -r '.model // ""' 2>/dev/null || echo "")"
      cli_version="$(printf '%s' "$init" | jq -r '.claude_code_version // ""' 2>/dev/null || echo "")"
      if printf '%s' "$init" | jq -e --arg f "$family" '(.skills // []) | index($f) != null' >/dev/null 2>&1; then
        skill_available=1
      fi
    fi

    # Per-run cost/effort and denials all come from the terminal result event.
    # Cost + turns are the efficiency companions to lift: a skill can be worth it
    # by reaching the answer sooner/cheaper even when quality lift is small.
    result_ev="$(grep '"type":"result"' "$stdout" 2>/dev/null | tail -1)"
    total_cost_usd="$(printf '%s' "$result_ev" | jq -r '.total_cost_usd // ""' 2>/dev/null || echo "")"
    num_turns="$(printf '%s' "$result_ev" | jq -r '.num_turns // ""' 2>/dev/null || echo "")"
    duration_ms="$(printf '%s' "$result_ev" | jq -r '.duration_ms // ""' 2>/dev/null || echo "")"
    result_subtype="$(printf '%s' "$result_ev" | jq -r '.subtype // ""' 2>/dev/null || echo "")"
    # A run that hit the per-run spend cap: definitive markers from the result event.
    terminal_reason="$(printf '%s' "$result_ev" | jq -r '.terminal_reason // ""' 2>/dev/null || echo "")"
    if [[ "$result_subtype" == "error_max_budget_usd" || "$terminal_reason" == "budget_exhausted" ]]; then
      budget_hit=1
    fi
    # A tool the model *attempted* but that dontAsk denied is not a real reach.
    # Net out permission_denials so a denied Skill/WebFetch is not read as activation.
    denials="$(printf '%s' "$result_ev" | jq -c '.permission_denials // []' 2>/dev/null || echo '[]')"
    skill_denied="$(printf '%s' "$denials" | jq '[.[]|select(.tool_name=="Skill")]|length' 2>/dev/null || echo 0)"
    wf_site_denied="$(printf '%s' "$denials" | jq '[.[]|select(.tool_name=="WebFetch")|select((.tool_input.url // "")|test("skills\\.qdrant\\.tech"))]|length' 2>/dev/null || echo 0)"
    bash_site_denied="$(printf '%s' "$denials" | jq '[.[]|select(.tool_name=="Bash")|select((.tool_input.command // "")|test("skills\\.qdrant\\.tech"))]|length' 2>/dev/null || echo 0)"

    # Activation/fetch signals: structural jq over the whole stream (robust to
    # whitespace and key-order changes, unlike string-matching). tool_use objects
    # are found by recursive descent so a re-nesting of the event schema survives.
    # If the slurp fails to parse, or init/result are absent, the transcript is not
    # the shape we expect: set signals_ok=0 and surface it, rather than silently
    # scoring activation=none (the No silent caps guardrail).
    sig="$(jq -rs --arg fam "$family" --arg leaf "$leaf" '
      [ .. | objects | select(.type? == "tool_use") ] as $t
      | [ ([$t[]|select(.name=="Skill")   |select((((.input.skill // .input.command) // "")|tostring)|contains($fam))]|length),
          ([$t[]|select(.name=="Read")    |select(((.input.file_path) // "")|test("skills/"+$fam+"/.*SKILL\\.md"))]|length),
          ([$t[]|select(.name=="Read")    |select(((.input.file_path) // "")|contains("skills/"+$leaf))]|length),
          ([$t[]|select(.name=="WebFetch")|select(((.input.url) // "")|contains("skills.qdrant.tech"))]|length),
          ([$t[]|select(.name=="Bash")    |select(((.input.command) // "")|contains("skills.qdrant.tech"))]|length)
        ] | @tsv' "$stdout" 2>/dev/null)"
    if [[ -n "$sig" && -n "$init" && -n "$result_ev" ]]; then
      IFS=$'\t' read -r skill_tool read_family read_leaf wf curlf <<< "$sig"
    else
      signals_ok=0
      skill_tool=0; read_family=0; read_leaf=0; wf=0; curlf=0
    fi

    # Subtract denied attempts (floor at 0).
    skill_tool=$(( skill_tool - skill_denied )); (( skill_tool < 0 )) && skill_tool=0
    fetched_count=$(( (wf - wf_site_denied) + (curlf - bash_site_denied) ))
    (( fetched_count < 0 )) && fetched_count=0

    [[ "$read_leaf" -gt 0 ]] && reached_leaf=1
    [[ "$fetched_count" -gt 0 ]] && fetched_site=1

    if [[ "$skill_tool" -gt 0 ]]; then
      activation="skill_tool"
    elif [[ "$read_family" -gt 0 ]]; then
      activation="file_read"
    elif [[ "$fetched_count" -gt 0 ]]; then
      activation="web_fetch"
    else
      activation="none"
    fi
  else
    model_snapshot="MISSING_TRANSCRIPT"
    signals_ok=0
  fi

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$base" "$skill_available" "$activation" "$reached_leaf" \
    "$fetched_site" "$fetched_count" "$model_snapshot" "$cli_version" \
    "$total_cost_usd" "$num_turns" "$result_subtype" "$budget_hit" "$signals_ok" "$duration_ms" >> "$tmp"
done

mv "$tmp" "$MANIFEST"
echo "Enriched manifest: $MANIFEST"

# Surface invalid with-skill runs (availability check failed) — the one hard gate.
invalid="$(awk -F, 'NR>1 && $5=="with-skill" && $11==0 {print $7}' "$MANIFEST")"
if [[ -n "$invalid" ]]; then
  echo "WARNING: with-skill runs where the skill was NOT available (invalid, exclude from scoring):" >&2
  printf '  %s\n' $invalid >&2
fi

# Budget-capped runs: truncated, excluded from scoring and the cost mean. ($21 = budget_hit)
capped="$(awk -F, 'NR>1 && $21==1 {print $7}' "$MANIFEST")"
if [[ -n "$capped" ]]; then
  echo "NOTE: budget-capped runs (hit the per-run \$ cap, truncated, excluded):" >&2
  printf '  %s\n' $capped >&2
fi

# Signals tripwire: a transcript we could not parse into the expected shape. Its
# activation/fetch numbers are NOT trustworthy (a format break, not a real
# activation=none) — surface it rather than let it read as a silent trigger miss.
# ($22 = signals_ok)
bad_signals="$(awk -F, 'NR>1 && $22==0 {print $7}' "$MANIFEST")"
if [[ -n "$bad_signals" ]]; then
  echo "WARNING: runs whose transcript did not parse to the expected shape" >&2
  echo "         (signals_ok=0 — activation/fetch numbers unreliable, investigate the format):" >&2
  printf '  %s\n' $bad_signals >&2
fi
