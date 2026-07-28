#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run-claude-test.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/run-claude-test-batch.sh [PASSTHROUGH_OPTS -- ] PATH [PATH...]

Runs run-claude-test.sh once per test-prompt. Each PATH is either:
  - a file (.json test-prompt or a plain prompt file), or
  - a directory (every *.json inside it is run, sorted by name).

Options placed before a literal `--` are forwarded verbatim to every
run-claude-test.sh invocation, e.g. --model, --skills-dir, --permission-mode.
With no `--`, all arguments are treated as PATHs.

The batch continues past a failing run and prints a pass/fail summary at the
end. It exits non-zero if any run failed.

Examples:
  scripts/run-claude-test-batch.sh ../evals/test-prompts
  scripts/run-claude-test-batch.sh --model sonnet -- a.json b.json
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

PASSTHROUGH=()
INPUTS=()

has_sep=0
for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    has_sep=1
    break
  fi
done

if [[ "$has_sep" == "1" ]]; then
  seen_sep=0
  for arg in "$@"; do
    if [[ "$seen_sep" == "0" && "$arg" == "--" ]]; then
      seen_sep=1
      continue
    fi
    if [[ "$seen_sep" == "0" ]]; then
      PASSTHROUGH+=("$arg")
    else
      INPUTS+=("$arg")
    fi
  done
else
  INPUTS=("$@")
fi

# Expand any directories into their *.json test-prompts (sorted, stable order).
FILES=()
for path in ${INPUTS[@]+"${INPUTS[@]}"}; do
  if [[ -d "$path" ]]; then
    shopt -s nullglob
    matches=("$path"/*.json)
    shopt -u nullglob
    if [[ "${#matches[@]}" -eq 0 ]]; then
      echo "No .json test-prompts in directory: $path" >&2
      continue
    fi
    while IFS= read -r match; do
      FILES+=("$match")
    done < <(printf '%s\n' "${matches[@]}" | sort)
  elif [[ -f "$path" ]]; then
    FILES+=("$path")
  else
    echo "Path not found: $path" >&2
    exit 66
  fi
done

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "No test-prompts to run" >&2
  usage >&2
  exit 64
fi

total="${#FILES[@]}"
pass=0
fail=0
FAILED=()

i=0
for file in "${FILES[@]}"; do
  i=$((i + 1))
  echo "=== [$i/$total] $file ==="
  if "$RUNNER" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"} "$file"; then
    pass=$((pass + 1))
  else
    status=$?
    fail=$((fail + 1))
    FAILED+=("$file")
    echo "Run failed (exit $status): $file" >&2
  fi
  echo
done

echo "Batch complete: $pass passed, $fail failed (of $total)."
if [[ "$fail" -gt 0 ]]; then
  printf 'Failed: %s\n' "${FAILED[@]}" >&2
  exit 1
fi
