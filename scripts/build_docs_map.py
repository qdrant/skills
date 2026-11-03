#!/usr/bin/env python3
"""Build docs-map.json: which Qdrant docs pages each skill draws on.

Scans every skills/**/SKILL.md for links to the Qdrant documentation
(https://skills.qdrant.tech/md/documentation/... or
https://qdrant.tech/documentation/...), normalizes them to docs URL paths,
merges hand-maintained overrides, and writes a deterministic JSON map.

The docs-to-skills automation (qdrant/documentation#167) uses the map to
find the candidate skills for a merged docs PR in qdrant/landing_page.

The map is not committed. build.sh generates it on every deploy, so the current version is always
at https://skills.qdrant.tech/docs-map.json, and the docs-to-skills workflow in qdrant/docs-automation
generates it from its own checkout before each run.

Usage:
  python3 scripts/build_docs_map.py                      # write docs-map.json (gitignored)
  python3 scripts/build_docs_map.py --output public/docs-map.json
  python3 scripts/build_docs_map.py --docs-root ../landing_page/qdrant-landing/content
                                                         # also verify pages and sections exist

Overrides (docs-map.overrides.json, hand-edited):
  {
    "qdrant-scaling/scaling-data-volume/horizontal-scaling": {
      "add": ["/documentation/scaling/resilience/"],
      "exclude": ["/documentation/overview/"]
    }
  }
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
OUTPUT = REPO_ROOT / "docs-map.json"
OVERRIDES = REPO_ROOT / "docs-map.overrides.json"

# skills.qdrant.tech/md/documentation/... proxies the docs as markdown;
# plain qdrant.tech/documentation/... links are accepted too.
LINK_RE = re.compile(
    r"https?://(?:skills\.qdrant\.tech/md|(?:www\.)?qdrant\.tech)"
    r"(/documentation/[^\s)\]>\"'`]*)"
)
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*(?:\{#([^}]+)\})?\s*$")


def normalize(raw: str) -> tuple[str, str | None]:
    """Turn a link path like /documentation/a/b/?s=sec#x into (page, section)."""
    parts = urlsplit(raw)
    path = parts.path
    if not path.endswith("/"):
        path += "/"
    path = re.sub(r"/{2,}", "/", path)
    section = None
    qs = parse_qs(parts.query).get("s")
    if qs:
        section = qs[0]
    elif parts.fragment:
        section = parts.fragment
    return path, section


def skill_id(skill_md: Path) -> str:
    return skill_md.parent.relative_to(SKILLS_DIR).as_posix()


def scan_skills() -> dict[str, dict[str, set[str]]]:
    result: dict[str, dict[str, set[str]]] = {}
    for skill_md in sorted(SKILLS_DIR.rglob("SKILL.md")):
        pages: dict[str, set[str]] = {}
        for match in LINK_RE.finditer(skill_md.read_text(encoding="utf-8")):
            page, section = normalize(match.group(1))
            secs = pages.setdefault(page, set())
            if section:
                secs.add(section)
        result[skill_id(skill_md)] = pages
    return result


def apply_overrides(skills: dict[str, dict[str, set[str]]], errors: list[str]) -> None:
    if not OVERRIDES.exists():
        return
    data = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    for sid, rules in data.items():
        if sid.startswith("_"):
            continue  # allow "_comment" keys
        if sid not in skills:
            errors.append(f"overrides: unknown skill '{sid}'")
            continue
        for raw in rules.get("exclude", []):
            page, section = normalize(raw)
            if section:
                skills[sid].get(page, set()).discard(section)
            else:
                skills[sid].pop(page, None)
        for raw in rules.get("add", []):
            page, section = normalize(raw)
            secs = skills[sid].setdefault(page, set())
            if section:
                secs.add(section)


def build(skills: dict[str, dict[str, set[str]]]) -> dict:
    by_skill = {
        sid: {page: sorted(secs) for page, secs in sorted(pages.items())}
        for sid, pages in sorted(skills.items())
    }
    by_page: dict[str, list[str]] = {}
    for sid, pages in by_skill.items():
        for page in pages:
            by_page.setdefault(page, []).append(sid)
    return {
        "_generated": "by scripts/build_docs_map.py from qdrant/skills; edit docs-map.overrides.json instead",
        "skills": by_skill,
        "pages": {page: sorted(sids) for page, sids in sorted(by_page.items())},
    }


def anchorize(text: str) -> str:
    """Approximate Hugo's default heading anchors."""
    text = re.sub(r"[`*\[\]()]", "", text).strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    return re.sub(r"\s+", "-", text)


def loose(anchor: str) -> str:
    """Compare anchors leniently: slug rules differ on underscores."""
    return anchor.replace("_", "-")


def source_for(page: str, content_root: Path) -> Path | None:
    rel = page.strip("/")
    for cand in (content_root / f"{rel}.md", content_root / rel / "_index.md"):
        if cand.exists():
            return cand
    # Hugo lowercases URLs, so running-with-gpu/ is served from running-with-GPU.md.
    # Match case-insensitively so the check also works on case-sensitive filesystems.
    parent = content_root / Path(rel).parent
    if parent.is_dir():
        name = Path(rel).name.lower()
        for child in parent.iterdir():
            if child.name.lower() == f"{name}.md":
                return child
    return None


def verify(result: dict, content_root: Path) -> list[str]:
    problems = []
    for page, sids in result["pages"].items():
        src = source_for(page, content_root)
        if src is None:
            problems.append(f"missing page {page} (used by {', '.join(sids)})")
            continue
        anchors = set()
        in_fence = False
        for line in src.read_text(encoding="utf-8").splitlines():
            if line.lstrip().startswith(("```", "~~~")):
                in_fence = not in_fence
                continue
            m = None if in_fence else HEADING_RE.match(line)
            if m:
                anchors.add(loose(m.group(2) or anchorize(m.group(1))))
        for sid in sids:
            for sec in result["skills"][sid][page]:
                if loose(sec) not in anchors:
                    problems.append(f"missing section {page}?s={sec} (used by {sid})")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--output", type=Path, default=OUTPUT, help="where to write the map (default: docs-map.json)")
    ap.add_argument("--docs-root", type=Path, help="landing_page/qdrant-landing/content, to verify links")
    ap.add_argument("--strict", action="store_true", help="with --docs-root, fail on missing pages or sections")
    args = ap.parse_args()

    errors: list[str] = []
    skills = scan_skills()
    apply_overrides(skills, errors)
    result = build(skills)
    text = json.dumps(result, indent=2, ensure_ascii=False) + "\n"

    for sid, pages in result["skills"].items():
        if pages:
            continue
        hub = any(SKILLS_DIR.joinpath(sid).glob("*/SKILL.md"))
        if hub:
            print(f"note: hub {sid} links to no docs pages (expected for routing-only hubs)", file=sys.stderr)
        else:
            print(f"warning: {sid} links to no docs pages; triage can never flag it", file=sys.stderr)

    problems = verify(result, args.docs_root) if args.docs_root else []
    for p in problems:
        print(f"warning: {p}", file=sys.stderr)

    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors or (args.strict and problems):
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text, encoding="utf-8")
    n_pages = len(result["pages"])
    print(f"wrote {args.output}: {len(result['skills'])} skills, {n_pages} docs pages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
