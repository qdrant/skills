#!/usr/bin/env python3
"""Generate an llms.txt map of the skill tree for the deployed site.

Walks the published SKILL.md files, reads each skill's name and description
from frontmatter, and emits a single `/llms.txt` following the llmstxt.org
convention: an H1 title, a short blockquote blurb, then a nested bullet list
of every skill linking to its markdown, with the routing description as notes.

Driving this from the filesystem (like generate_sitemap.sh) means the map can
never drift from the skills that actually ship — new skills appear
automatically, deleted ones disappear. Title and blurb are lifted from
index.md so the curated voice stays in one place.
"""

import os
import sys

from make_links_absolute import _site_url

SEARCH_URL = "https://skills.qdrant.tech/search?query=your+query+here"
DEFAULT_TITLE = "Qdrant Skills"
DEFAULT_BLURB = "Agent skills encoding deep Qdrant knowledge for coding agents."


def parse_frontmatter(content):
    """Return a {key: value} dict of the leading YAML frontmatter block."""
    if not content.startswith("---"):
        return {}
    end = content.find("---", 3)
    if end == -1:
        return {}
    fm = {}
    for line in content[3:end].strip().split("\n"):
        line = line.strip()
        if ":" in line and not line.startswith("-"):
            key, val = line.split(":", 1)
            fm[key.strip()] = val.strip().strip('"')
    return fm


def title_and_blurb(public_dir):
    """Lift the H1 title and first paragraph from index.md; fall back to defaults."""
    index_path = os.path.join(public_dir, "index.md")
    title, blurb = DEFAULT_TITLE, DEFAULT_BLURB
    try:
        with open(index_path) as f:
            lines = f.read().splitlines()
    except OSError:
        return title, blurb
    for line in lines:
        if line.startswith("# "):
            title = line[2:].strip()
            break
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            blurb = stripped
            break
    return title, blurb


def collect_skills(public_dir):
    """Return a sorted list of (depth, name, url_path, description) for every skill.

    depth 0 is a top-level skill; deeper values are sub-skills nested under a
    hub, derived from how many directories sit between the file and public/.
    """
    base_url = _site_url()
    skills = []
    for root, _dirs, files in os.walk(public_dir):
        if "SKILL.md" not in files:
            continue
        filepath = os.path.join(root, "SKILL.md")
        rel_dir = os.path.relpath(root, public_dir)
        # A SKILL.md sitting directly in public/ (rel_dir ".") would be the
        # site index, not a skill; skip it.
        if rel_dir == os.curdir:
            continue
        segments = rel_dir.split(os.sep)
        depth = len(segments) - 1
        with open(filepath) as f:
            fm = parse_frontmatter(f.read())
        name = fm.get("name") or segments[-1]
        description = fm.get("description", "").strip()
        url = f"{base_url}/{rel_dir.replace(os.sep, '/')}/SKILL.md"
        # Sort key keeps children directly beneath their parent while ordering
        # each level alphabetically by path.
        skills.append((tuple(segments), depth, name, url, description))
    skills.sort(key=lambda s: s[0])
    return [(depth, name, url, desc) for _segments, depth, name, url, desc in skills]


def render(title, blurb, skills):
    lines = [f"# {title}", "", f"> {blurb}", "", "## Skills", ""]
    for depth, name, url, description in skills:
        indent = "  " * depth
        bullet = f"{indent}- [{name}]({url})"
        if description:
            bullet += f": {description}"
        lines.append(bullet)
    lines += [
        "",
        "## Search",
        "",
        f"Full-text search across all skills: [{SEARCH_URL}]({SEARCH_URL})",
        "",
    ]
    return "\n".join(lines)


def run(public_dir):
    title, blurb = title_and_blurb(public_dir)
    skills = collect_skills(public_dir)
    output = render(title, blurb, skills)
    out_path = os.path.join(public_dir, "llms.txt")
    with open(out_path, "w") as f:
        f.write(output)
    print(f"llms.txt generated at {out_path} ({len(skills)} skills)")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "public")
