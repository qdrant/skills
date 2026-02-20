#!/usr/bin/env bash
set -euo pipefail

# Validate all skill definitions for structural correctness.
# Usage: bash scripts/test-skills.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
ERRORS=0
TESTS=0
PASSED=0

pass() {
    TESTS=$((TESTS + 1))
    PASSED=$((PASSED + 1))
    echo "  pass: $1"
}

fail() {
    TESTS=$((TESTS + 1))
    ERRORS=$((ERRORS + 1))
    echo "  FAIL: $1"
}

echo "=== skill structure tests ==="
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name="$(basename "$skill_dir")"
    echo "[$skill_name]"

    # 1. SKILL.md exists
    if [ -f "$skill_dir/SKILL.md" ]; then
        pass "SKILL.md exists"
    else
        fail "SKILL.md missing"
        continue
    fi

    # 2. SKILL.md starts with frontmatter delimiter
    if head -1 "$skill_dir/SKILL.md" | grep -q '^---$'; then
        pass "SKILL.md has frontmatter opening"
    else
        fail "SKILL.md missing frontmatter opening ---"
    fi

    # 3. SKILL.md has closing frontmatter delimiter
    if awk 'NR>1' "$skill_dir/SKILL.md" | grep -q '^---$'; then
        pass "SKILL.md has frontmatter closing"
    else
        fail "SKILL.md missing frontmatter closing ---"
    fi

    # 4. Frontmatter has required 'name' field
    if grep -q '^name:' "$skill_dir/SKILL.md"; then
        pass "SKILL.md has name field"
    else
        fail "SKILL.md missing name field"
    fi

    # 5. Frontmatter 'name' matches directory name
    fm_name=$(grep '^name:' "$skill_dir/SKILL.md" | head -1 | sed 's/^name: *//')
    if [ "$fm_name" = "$skill_name" ]; then
        pass "SKILL.md name matches directory ($fm_name)"
    else
        fail "SKILL.md name '$fm_name' does not match directory '$skill_name'"
    fi

    # 6. Frontmatter has required 'description' field
    if grep -q '^description:' "$skill_dir/SKILL.md"; then
        pass "SKILL.md has description field"
    else
        fail "SKILL.md missing description field"
    fi

    # 7. allowed-tools is space-delimited string (not YAML list)
    if grep -q '^allowed-tools:' "$skill_dir/SKILL.md"; then
        at_line=$(grep '^allowed-tools:' "$skill_dir/SKILL.md")
        if echo "$at_line" | grep -q '^allowed-tools: [A-Za-z]'; then
            pass "allowed-tools is space-delimited string"
        else
            fail "allowed-tools appears to be YAML list instead of space-delimited string"
        fi
    else
        fail "SKILL.md missing allowed-tools field"
    fi

    # 8. Has license field
    if grep -q '^license:' "$skill_dir/SKILL.md"; then
        pass "SKILL.md has license field"
    else
        fail "SKILL.md missing license field"
    fi

    # 9. Has metadata section
    if grep -q '^metadata:' "$skill_dir/SKILL.md"; then
        pass "SKILL.md has metadata field"
    else
        fail "SKILL.md missing metadata field"
    fi

    # 10. AGENTS.md exists
    if [ -f "$skill_dir/AGENTS.md" ]; then
        pass "AGENTS.md exists"
    else
        fail "AGENTS.md missing"
    fi

    # 11. AGENTS.md does NOT have frontmatter (it should be plain markdown)
    if [ -f "$skill_dir/AGENTS.md" ]; then
        if head -1 "$skill_dir/AGENTS.md" | grep -q '^---$'; then
            fail "AGENTS.md should not have frontmatter (that belongs in SKILL.md)"
        else
            pass "AGENTS.md has no frontmatter"
        fi
    fi

    # 12. AGENTS.md is not identical to SKILL.md
    if [ -f "$skill_dir/AGENTS.md" ]; then
        if diff -q "$skill_dir/SKILL.md" "$skill_dir/AGENTS.md" > /dev/null 2>&1; then
            fail "AGENTS.md is identical to SKILL.md (should be compressed version)"
        else
            pass "AGENTS.md differs from SKILL.md"
        fi
    fi

    # 13. AGENTS.md is smaller than SKILL.md (compressed)
    if [ -f "$skill_dir/AGENTS.md" ]; then
        skill_size=$(wc -c < "$skill_dir/SKILL.md")
        agents_size=$(wc -c < "$skill_dir/AGENTS.md")
        if [ "$agents_size" -lt "$skill_size" ]; then
            pass "AGENTS.md ($agents_size bytes) < SKILL.md ($skill_size bytes)"
        else
            fail "AGENTS.md ($agents_size bytes) should be smaller than SKILL.md ($skill_size bytes)"
        fi
    fi

    # 14. SKILL.md contains a Gotchas section
    if grep -q '## Gotchas' "$skill_dir/SKILL.md"; then
        pass "SKILL.md has Gotchas section"
    else
        fail "SKILL.md missing Gotchas section"
    fi

    # 15. AGENTS.md contains a Gotchas section
    if [ -f "$skill_dir/AGENTS.md" ]; then
        if grep -q '## Gotchas' "$skill_dir/AGENTS.md" || grep -q 'Gotchas' "$skill_dir/AGENTS.md"; then
            pass "AGENTS.md has Gotchas section"
        else
            fail "AGENTS.md missing Gotchas section"
        fi
    fi

    # 16. No em-dashes in any file
    for f in "$skill_dir"/*.md; do
        fname="$(basename "$f")"
        if grep -Pq '\x{2014}' "$f" 2>/dev/null || grep -q '—' "$f"; then
            fail "$fname contains em-dash"
        else
            pass "$fname has no em-dashes"
        fi
    done

    echo ""
done

echo "=== repo structure tests ==="
echo ""

# Plugin manifest exists
if [ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]; then
    pass "plugin.json exists"
else
    fail "plugin.json missing"
fi

# Plugin manifest is valid JSON
if python3 -c "import json; json.load(open('$REPO_ROOT/.claude-plugin/plugin.json'))" 2>/dev/null; then
    pass "plugin.json is valid JSON"
else
    fail "plugin.json is not valid JSON"
fi

# README exists
if [ -f "$REPO_ROOT/README.md" ]; then
    pass "README.md exists"
else
    fail "README.md missing"
fi

# README lists all skills
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name="$(basename "$skill_dir")"
    if grep -q "$skill_name" "$REPO_ROOT/README.md"; then
        pass "README mentions $skill_name"
    else
        fail "README does not mention $skill_name"
    fi
done

# start-qdrant.sh exists and is executable
if [ -x "$REPO_ROOT/scripts/start-qdrant.sh" ]; then
    pass "scripts/start-qdrant.sh exists and is executable"
else
    fail "scripts/start-qdrant.sh missing or not executable"
fi

# Makefile exists
if [ -f "$REPO_ROOT/Makefile" ]; then
    pass "Makefile exists"
else
    fail "Makefile missing"
fi

# No AGENTS.md files that are identical to SKILL.md (repo-wide check already done per skill)

echo ""
echo "=== results ==="
echo "$PASSED/$TESTS passed, $ERRORS failed"

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
