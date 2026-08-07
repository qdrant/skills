#!/usr/bin/env bash
# Weekly scoring matrix: run every scored test-prompt across models x conditions
# x reps, capturing each run under a dated weekly dir and recording a base
# manifest row. Signals (availability/activation/fetches) are added afterwards by
# extract-run-signals.sh, which reads this manifest and the captured transcripts.
#
#   models      default sonnet,haiku
#   conditions  no-skill (nothing installed) and with-skill (isolated family)
#   reps        default 2 (see SCORING.md: cost-first, raise later)
#
# The with-skill arm installs ONLY the one top-level skill family the prompt maps
# to, so lift is attributable to that skill. It stages the family into a temp dir
# and mounts that, so the container's per-child install path registers it under
# its real name (not "mounted-skill") — which is what the availability check and
# activation detection key on.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=resolve-skill.sh
source "$SCRIPT_DIR/resolve-skill.sh"

MODELS="sonnet,haiku"
CONDITIONS="no-skill,with-skill"
REPS="2"
PROMPTS_DIR="${PROMPTS_DIR:-$REPO_ROOT/evals/test-prompts}"
SKILLS_ROOT="${SKILLS_ROOT:-$REPO_ROOT/skills}"
HARNESS="${HARNESS:-$REPO_ROOT/skill-test/scripts/run-claude-test.sh}"
OUT_DIR=""
PERMISSION_MODE="dontAsk"
# Under dontAsk the run cannot wander off-task, but the tools scoring depends on
# (the Skill tool, web search/fetch) are denied unless pre-approved. Allow the
# same set in BOTH arms so lift is measured with web enabled and the skill
# usable, exactly as SCORING.md's tool-parity section requires. Comma-separated
# (single token) so it is not confused with the prompt positional.
ALLOWED_TOOLS="Skill,WebSearch,WebFetch,Read,Grep,Glob,Bash"
MAX_TURNS="20"
# Per-run spend cap (a runaway backstop, not a routine limiter). A run that hits
# it stops truncated and is excluded from scoring/cost and marked budget-capped.
MAX_BUDGET_USD="2.00"
DRY_RUN="0"
LIMIT="0"
# Concurrent runs. Runs are API-latency-bound, so 2-3 roughly halves/thirds
# wall-time at negligible local cost. It does NOT change results or spend — only
# wall-time. Keep small: >=4 risks hitting API rate limits.
JOBS="1"
DATE_TAG="$(date -u +%Y%m%d)"

usage() {
  cat <<'USAGE'
Usage: scripts/scoring/run-eval-matrix.sh [options]

Runs the 2x2xk scoring matrix over the scored (non-discord) test-prompts.

Options:
  --models LIST         Comma list of models. Default: sonnet,haiku
  --conditions LIST     Comma list of no-skill,with-skill. Default: both
  --reps N              Repetitions per cell. Default: 2
  --jobs N              Runs to execute concurrently. Default: 1 (sequential).
                        Changes wall-time only, not results or cost; 2-3 is the
                        sweet spot, >=4 risks API rate limits.
  --prompts-dir DIR     Test-prompt JSONs. Default: ../skills/evals/test-prompts
  --skills-root DIR     Skills root for staging. Default: ../skills/skills
  --out-dir DIR         Weekly output dir. Default: runs/weekly/<UTC-date>
  --permission-mode M   Passed to the harness. Default: dontAsk
  --allowed-tools LIST  Comma-separated tools pre-approved in BOTH arms under
                        dontAsk. Default: Skill,WebSearch,WebFetch,Read,Grep,Glob,Bash
                        Empty string disables the allow-list.
  --max-turns N         Passed to the harness. Default: 20
  --max-budget-usd USD  Per-run spend cap (runaway backstop). Default: 2.00
                        Empty string disables the cap.
  --limit N             Only the first N scored prompts (smoke). Default: all
  --dry-run             Print the plan and manifest path; run nothing.
  -h, --help            Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --models) MODELS="${2:?}"; shift 2 ;;
    --conditions) CONDITIONS="${2:?}"; shift 2 ;;
    --reps) REPS="${2:?}"; shift 2 ;;
    --jobs) JOBS="${2:?}"; shift 2 ;;
    --prompts-dir) PROMPTS_DIR="${2:?}"; shift 2 ;;
    --skills-root) SKILLS_ROOT="${2:?}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:?}"; shift 2 ;;
    --permission-mode) PERMISSION_MODE="${2:?}"; shift 2 ;;
    # `${2?...}` (no colon) accepts an explicit "" (disables the feature, per the
    # usage text) but still errors when the value is genuinely missing.
    --allowed-tools) ALLOWED_TOOLS="${2?--allowed-tools needs a value (use \"\" to disable)}"; shift 2 ;;
    --max-turns) MAX_TURNS="${2:?}"; shift 2 ;;
    --max-budget-usd) MAX_BUDGET_USD="${2?--max-budget-usd needs a value (use \"\" to disable)}"; shift 2 ;;
    --limit) LIMIT="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -d "$PROMPTS_DIR" ]] || { echo "Prompts dir not found: $PROMPTS_DIR" >&2; exit 66; }
[[ -d "$SKILLS_ROOT" ]] || { echo "Skills root not found: $SKILLS_ROOT" >&2; exit 66; }

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid --jobs '$JOBS' (want a positive integer)" >&2; exit 64; }
if [[ "$JOBS" -ge 4 ]]; then
  echo "Warning: --jobs $JOBS — high concurrency may hit API rate limits; 2-3 is the sweet spot." >&2
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$REPO_ROOT/evals/weekly/$DATE_TAG"
fi
MANIFEST="$OUT_DIR/manifest.csv"

IFS=',' read -r -a MODEL_ARR <<< "$MODELS"
IFS=',' read -r -a COND_ARR <<< "$CONDITIONS"

for c in "${COND_ARR[@]}"; do
  case "$c" in
    no-skill|with-skill) ;;
    *) echo "Invalid condition: $c (want no-skill or with-skill)" >&2; exit 64 ;;
  esac
done

# Collect scored prompts (skip discord-), sorted. (Portable to bash 3.2 — no mapfile.)
PROMPTS=()
while IFS= read -r _pf; do
  [[ -n "$_pf" ]] && PROMPTS+=("$_pf")
done < <(find "$PROMPTS_DIR" -maxdepth 1 -name '*.json' ! -name 'discord-*' | sort)
if [[ "$LIMIT" -gt 0 && "${#PROMPTS[@]}" -gt "$LIMIT" ]]; then
  PROMPTS=("${PROMPTS[@]:0:$LIMIT}")
fi

n_prompts="${#PROMPTS[@]}"
total=$((n_prompts * ${#MODEL_ARR[@]} * ${#COND_ARR[@]} * REPS))

# Skills commit for provenance (records what the with-skill arm actually mounted).
skills_sha="unknown"
if command -v git >/dev/null 2>&1; then
  skills_sha="$(git -C "$SKILLS_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

echo "Weekly scoring matrix"
echo "  out-dir:    $OUT_DIR"
echo "  models:     ${MODEL_ARR[*]}"
echo "  conditions: ${COND_ARR[*]}"
echo "  reps:       $REPS"
echo "  prompts:    $n_prompts scored"
echo "  skills_sha: $skills_sha"
echo "  total runs: $total"
echo "  jobs:       $JOBS concurrent"
echo "  mode:       $PERMISSION_MODE  max-turns: $MAX_TURNS  budget: ${MAX_BUDGET_USD:-none}"
echo "  allowed:    ${ALLOWED_TOOLS:-<none>}"
echo

# Each task writes its manifest row to its own file here; they are concatenated
# (sorted) into manifest.csv after all workers finish, so concurrent writes never
# race on a single file.
MANIFEST_DIR="$OUT_DIR/.manifest.d"

if [[ "$DRY_RUN" != "1" ]]; then
  mkdir -p "$OUT_DIR" "$MANIFEST_DIR"
  if [[ ! -f "$MANIFEST" ]]; then
    echo "prompt,skill_family,skill_leaf,model,condition,rep,run_id,exit_code,skills_sha,timestamp" > "$MANIFEST"
  fi
fi

run_one() {
  local prompt_file="$1" model="$2" condition="$3" rep="$4"
  local name url resolved family leaf
  name="$(jq -r '.name // empty' "$prompt_file")"
  [[ -n "$name" ]] || name="$(basename "$prompt_file" .json)"
  url="$(jq -r '.skill_url // empty' "$prompt_file")"

  if ! resolved="$(resolve_skill "$url")"; then
    echo "  !! skip $name: unresolvable skill_url ($url)" >&2
    return 1
  fi
  family="${resolved%%$'\t'*}"
  leaf="${resolved#*$'\t'}"

  local args=(
    --model "$model"
    --permission-mode "$PERMISSION_MODE"
    --max-turns "$MAX_TURNS"
    --runs-dir "$OUT_DIR"
    --no-render
  )
  # Trailing `--` ends the variadic --allowedTools list so the container's prompt
  # positional (claude ... "$prompt") is not swallowed as a tool name.
  [[ -n "$ALLOWED_TOOLS" ]] && args+=(--extra-args "--allowedTools $ALLOWED_TOOLS --")
  [[ -n "$MAX_BUDGET_USD" ]] && args+=(--max-budget-usd "$MAX_BUDGET_USD")

  local stage=""
  if [[ "$condition" == "with-skill" ]]; then
    stage="$(mktemp -d)"
    # Copy the whole family subtree under its real name so progressive-disclosure
    # relative links resolve and the container installs it as ~/.claude/skills/<family>.
    cp -R "$SKILLS_ROOT/$family" "$stage/$family"
    args+=(--skills-dir "$stage")
  fi

  # Descriptive, unique-per-task run id — passed to the harness via --run-id so
  # concurrent runs never share a dir or Docker --name. All chars are safe.
  local run_id="$name-$model-$condition-r$rep"
  args+=(--run-id "$run_id")

  local ts exit_code tmplog
  ts="$(date -u +%Y%m%dT%H%M%SZ)"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY  %-42s %-7s %-11s rep=%s  install=%s\n' \
      "$name" "$model" "$condition" "$rep" \
      "$([[ "$condition" == with-skill ]] && echo "$family" || echo none)"
    [[ -n "$stage" ]] && rm -rf "$stage"
    return 0
  fi

  # Capture harness output per-task so parallel workers don't interleave on the console.
  tmplog="$(mktemp)"
  set +e
  "$HARNESS" "${args[@]}" "$prompt_file" >"$tmplog" 2>&1
  exit_code=$?
  set -e
  rm -f "$tmplog"
  [[ -n "$stage" ]] && rm -rf "$stage"

  # One row per task, written to its own file — concatenated after the pool drains.
  echo "$name,$family,$leaf,$model,$condition,$rep,$run_id,$exit_code,$skills_sha,$ts" \
    > "$MANIFEST_DIR/$run_id.row"
  printf '  ok   %-42s %-7s %-11s rep=%s  run_id=%s exit=%s\n' \
    "$name" "$model" "$condition" "$rep" "$run_id" "$exit_code"
  return 0
}

# Build the flat task list (prompt × model × condition × rep).
tasks=()
for prompt_file in "${PROMPTS[@]}"; do
  for model in "${MODEL_ARR[@]}"; do
    for condition in "${COND_ARR[@]}"; do
      for ((rep = 1; rep <= REPS; rep++)); do
        tasks+=("$prompt_file"$'\t'"$model"$'\t'"$condition"$'\t'"$rep")
      done
    done
  done
done

# Rolling PID pool: keep up to $JOBS workers in flight (bash 3.2-safe — no
# `wait -n`). Poll for any finished worker before launching the next.
pids=()
reap_one() {
  while :; do
    local i
    for i in "${!pids[@]}"; do
      if ! kill -0 "${pids[$i]}" 2>/dev/null; then
        wait "${pids[$i]}" 2>/dev/null || true
        unset 'pids[$i]'
        return 0
      fi
    done
    sleep 1
  done
}

for task in "${tasks[@]}"; do
  IFS=$'\t' read -r tf tm tc tr <<< "$task"
  if [[ "$JOBS" -le 1 || "$DRY_RUN" == "1" ]]; then
    run_one "$tf" "$tm" "$tc" "$tr" || true
  else
    (( ${#pids[@]} >= JOBS )) && reap_one
    run_one "$tf" "$tm" "$tc" "$tr" &
    pids+=("$!")
  fi
done
[[ "$JOBS" -gt 1 && "$DRY_RUN" != "1" ]] && wait

# Assemble the manifest from per-task rows in a deterministic order.
if [[ "$DRY_RUN" != "1" ]]; then
  if compgen -G "$MANIFEST_DIR/*.row" >/dev/null; then
    cat "$MANIFEST_DIR"/*.row | sort >> "$MANIFEST"
  fi
  rm -rf "$MANIFEST_DIR"
fi

echo
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run: $total runs planned. Manifest would be: $MANIFEST"
else
  echo "Matrix complete. Manifest: $MANIFEST"
  echo "Next: scripts/scoring/extract-run-signals.sh --out-dir \"$OUT_DIR\""
fi
