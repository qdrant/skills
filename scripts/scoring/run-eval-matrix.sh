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
# Concurrent runs. At the recommended 2-3, runs are API-latency-bound, so this
# roughly halves/thirds wall-time at negligible local cost and does NOT change
# results or spend. Do not go higher: >=4 risks API rate limits, and a
# rate-limited run can change results.
JOBS="1"
DATE_TAG="$(date -u +%Y%m%d)"
# Stamped once per invocation. Appended to each run id so ids are deterministic
# *within* a run but unique *across* invocations — re-running (e.g. after a
# partial failure) into the same out-dir can't clobber a prior run's transcript
# or double-count its manifest rows.
RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

usage() {
  cat <<'USAGE'
Usage: scripts/scoring/run-eval-matrix.sh [options]

Runs the 2x2xk scoring matrix over the scored (non-discord) test-prompts.

Options:
  --models LIST         Comma list of models. Default: sonnet,haiku
  --conditions LIST     Comma list of no-skill,with-skill. Default: both
  --reps N              Repetitions per cell. Default: 2
  --jobs N              Runs to execute concurrently. Default: 1 (sequential).
                        At the recommended 2-3, changes wall-time only, not
                        results or cost; >=4 risks API rate limits (which can
                        change results).
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
# race on a single file. The dir is stamped per invocation so two overlapping runs
# into the same out-dir never clobber each other's rows (and so it's never stale —
# no destructive startup cleanup needed).
MANIFEST_DIR="$OUT_DIR/.manifest.d-$RUN_STAMP"
# Worker skill-staging dirs live under a per-invocation temp base (NOT under
# $OUT_DIR): staging is the bind-mount source for --skills-dir, so keeping it out
# of the shared out-dir means a sibling run can't yank it from a live container.
# Set only for real runs; cleaned by the trap / at the end.
STAGE_BASE=""

if [[ "$DRY_RUN" != "1" ]]; then
  STAGE_BASE="$(mktemp -d "${TMPDIR:-/tmp}/skill-eval-stage.XXXXXX")"
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

  # Descriptive, unique-per-invocation run id. Slugified so an odd char in the
  # prompt .name (space, :, /) can't reach --run-id raw; RUN_STAMP makes it unique
  # across invocations so a re-run into the same out-dir never clobbers a prior
  # run's transcript or double-counts its manifest row.
  local run_id
  run_id="$(printf '%s' "$name-$model-$condition-r$rep-$RUN_STAMP" | tr -c 'A-Za-z0-9._-' '_')"
  # The harness requires the id to start with a letter/digit (Docker's --name
  # rule); slugify keeps a leading -/. so guard it here.
  [[ "$run_id" =~ ^[A-Za-z0-9] ]] || run_id="r-$run_id"

  # Dry-run needs only $family for the printout — return before any staging so no
  # mktemp/cp runs (STAGE_BASE isn't even created in dry mode).
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY  %-42s %-7s %-11s rep=%s  install=%s\n' \
      "$name" "$model" "$condition" "$rep" \
      "$([[ "$condition" == with-skill ]] && echo "$family" || echo none)"
    return 0
  fi

  local stage=""
  if [[ "$condition" == "with-skill" ]]; then
    stage="$(mktemp -d "$STAGE_BASE/stage.XXXXXX")"
    # Copy the whole family subtree under its real name so progressive-disclosure
    # relative links resolve and the container installs it as ~/.claude/skills/<family>.
    cp -R "$SKILLS_ROOT/$family" "$stage/$family"
    args+=(--skills-dir "$stage")
  fi

  args+=(--run-id "$run_id")

  local ts exit_code tmplog
  ts="$(date -u +%Y%m%dT%H%M%SZ)"

  # Capture harness output per-task so parallel workers don't interleave on the
  # console; keep it as a diagnostic if the run failed, discard it otherwise.
  tmplog="$(mktemp)"
  set +e
  "$HARNESS" "${args[@]}" "$prompt_file" >"$tmplog" 2>&1
  exit_code=$?
  set -e
  if [[ "$exit_code" -ne 0 ]]; then
    mv "$tmplog" "$OUT_DIR/$run_id.harness.log"
  else
    rm -f "$tmplog"
  fi
  [[ -n "$stage" ]] && rm -rf "$stage"

  # One row per task, written to its own file — concatenated after the pool drains.
  echo "$name,$family,$leaf,$model,$condition,$rep,$run_id,$exit_code,$skills_sha,$ts" \
    > "$MANIFEST_DIR/$run_id.row"
  local status_word="ok  "
  [[ "$exit_code" -ne 0 ]] && status_word="FAIL"
  printf '  %s %-42s %-7s %-11s rep=%s  run_id=%s exit=%s\n' \
    "$status_word" "$name" "$model" "$condition" "$rep" "$run_id" "$exit_code"
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

# Recursively SIGTERM a process and all its descendants (children first). A worker
# subshell has a harness child which in turn has a `docker run` child; killing only
# the tracked worker pid would orphan those, so walk the whole tree. SIGTERM (not
# KILL) lets `docker run` forward the signal so its `--rm` container stops cleanly.
kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$child"; done
  kill "$pid" 2>/dev/null || true
}

# On Ctrl-C / termination, stop the whole pool and clear temp state rather than
# leaving orphaned workers, containers, and half-written temp dirs.
cleanup_interrupt() {
  trap - INT TERM
  echo >&2
  echo "Interrupted — stopping workers and cleaning up..." >&2
  local p
  for p in "${pids[@]:-}"; do [[ -n "$p" ]] && kill_tree "$p"; done
  wait 2>/dev/null || true
  # Completed runs already cost API spend — keep their rows so the partial matrix
  # can still be extracted/judged/topped-up (matches pre-parallelism behavior).
  if compgen -G "$MANIFEST_DIR/*.row" >/dev/null 2>&1; then
    local n; n="$(find "$MANIFEST_DIR" -name '*.row' | wc -l | tr -d ' ')"
    cat "$MANIFEST_DIR"/*.row | sort >> "$MANIFEST"
    echo "Kept $n completed run(s) in $MANIFEST" >&2
  fi
  rm -rf "$MANIFEST_DIR"
  [[ -n "$STAGE_BASE" ]] && rm -rf "$STAGE_BASE"
  exit 130
}
trap cleanup_interrupt INT TERM

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
  trap - INT TERM
  if compgen -G "$MANIFEST_DIR/*.row" >/dev/null; then
    cat "$MANIFEST_DIR"/*.row | sort >> "$MANIFEST"
  fi
  rm -rf "$MANIFEST_DIR" "$STAGE_BASE"
fi

echo
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run: $total runs planned. Manifest would be: $MANIFEST"
else
  echo "Matrix complete. Manifest: $MANIFEST"
  echo "Next: scripts/scoring/extract-run-signals.sh --out-dir \"$OUT_DIR\""
fi
