#!/usr/bin/env python3
"""Validate SKILL.md files against quality checklist."""

import os
import re
import sys
from pathlib import Path


def parse_frontmatter(content: str) -> dict | None:
    if not content.startswith("---"):
        return None
    end = content.find("---", 3)
    if end == -1:
        return None
    raw = content[3:end].strip()
    fm = {}
    for line in raw.split("\n"):
        line = line.strip()
        if ":" in line and not line.startswith("-"):
            key, val = line.split(":", 1)
            fm[key.strip()] = val.strip().strip('"')
        elif line.startswith("- ") and "allowed-tools" in fm:
            if "tools_list" not in fm:
                fm["tools_list"] = []
            fm["tools_list"].append(line[2:].strip())
    if "allowed-tools" in fm:
        fm["tools_list"] = fm.get("tools_list", [])
    return fm


def is_hub(path: Path, content: str) -> bool:
    """Hub skills are directories containing sub-skill directories."""
    parent = path.parent
    subdirs = [d for d in parent.iterdir() if d.is_dir() and (d / "SKILL.md").exists()]
    return len(subdirs) > 0


def get_body(content: str) -> str:
    if not content.startswith("---"):
        return content
    end = content.find("---", 3)
    if end == -1:
        return content
    return content[end + 3:].strip()


def validate_skill(path: Path) -> list[str]:
    errors = []
    content = path.read_text()
    lines = content.strip().split("\n")
    line_count = len(lines)
    body = get_body(content)
    fm = parse_frontmatter(content)
    hub = is_hub(path, content)
    label = "hub" if hub else "leaf"

    # --- Frontmatter ---
    if fm is None:
        errors.append(f"FAIL [frontmatter] missing frontmatter ({label})")
        return errors

    if not fm.get("name"):
        errors.append(f"FAIL [frontmatter] missing 'name' field")

    if not fm.get("description"):
        errors.append(f"FAIL [frontmatter] missing 'description' field")

    # --- Description trigger phrases ---
    desc = fm.get("description", "")
    if desc and "use when" not in desc.lower():
        errors.append(f"WARN [activation] description missing 'Use when' trigger phrases")

    # --- allowed-tools ---
    has_tools = "tools_list" in fm
    skill_name = fm.get("name", "")
    # qdrant-clients-sdk is a leaf that needs Bash for curl snippet search
    needs_tools_exception = skill_name == "qdrant-clients-sdk"
    if hub and not has_tools:
        errors.append(f"FAIL [permissions] hub skill missing 'allowed-tools'")
    if not hub and has_tools and not needs_tools_exception:
        errors.append(f"FAIL [permissions] leaf skill should not have 'allowed-tools'")

    # --- What NOT to Do ---
    if not hub and "What NOT to Do" not in body:
        errors.append(f"WARN [structure] missing 'What NOT to Do' section")

    # --- No code blocks in skills (allow qdrant-clients-sdk as exception) ---
    if "```" in body and skill_name != "qdrant-clients-sdk":
        errors.append(f"FAIL [content] code blocks found (code belongs in commands/)")

    # --- Sizing ---
    if not hub:
        if line_count < 20:
            errors.append(f"WARN [sizing] only {line_count} lines (expected 40-80 for leaf)")
        elif line_count > 100:
            errors.append(f"WARN [sizing] {line_count} lines (consider splitting into hub + sub-skills)")

    # --- Raw URLs (not wrapped in markdown links) ---
    raw_url_pattern = re.compile(r'(?<!\()(https?://[^\s)]+)(?!\))')
    for i, line in enumerate(lines, 1):
        # skip lines that are already markdown links [text](url)
        cleaned = re.sub(r'\[.*?\]\(.*?\)', '', line)
        matches = raw_url_pattern.findall(cleaned)
        for url in matches:
            errors.append(f"WARN [formatting] line {i}: raw URL not wrapped in markdown link")
            break

    # --- Bullet consistency (no bullet-point char) ---
    if "\u2022" in body:
        errors.append(f"FAIL [formatting] uses bullet character, use '-' instead")

    # --- No generic intro ---
    first_para = body.split("\n\n")[0] if body else ""
    generic_openers = ["this document provides", "this skill provides", "this guide provides"]
    for opener in generic_openers:
        if opener in first_para.lower():
            errors.append(f"WARN [opening] generic introduction detected")
            break

    # --- Em-dash check ---
    if "\u2014" in body:
        errors.append(f"WARN [formatting] contains em-dash character")

    return errors


def main():
    skills_dir = Path(__file__).parent.parent / "skills"
    if not skills_dir.exists():
        print(f"error: skills directory not found at {skills_dir}")
        sys.exit(1)

    skill_files = sorted(skills_dir.rglob("SKILL.md"))
    total_errors = 0
    total_warns = 0
    total_pass = 0

    for path in skill_files:
        rel = path.relative_to(skills_dir.parent)
        errors = validate_skill(path)

        fails = [e for e in errors if e.startswith("FAIL")]
        warns = [e for e in errors if e.startswith("WARN")]

        if not errors:
            print(f"  PASS  {rel}")
            total_pass += 1
        else:
            for e in errors:
                prefix = "FAIL" if e.startswith("FAIL") else "WARN"
                print(f"  {prefix}  {rel}: {e.split('] ', 1)[1]}")

        total_errors += len(fails)
        total_warns += len(warns)

    print()
    print(f"results: {len(skill_files)} skills, {total_pass} clean, {total_errors} errors, {total_warns} warnings")

    if total_errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
