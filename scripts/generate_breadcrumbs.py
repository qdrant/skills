#!/usr/bin/env python3
"""Inject a navigation breadcrumb into every nested skill page.

An agent that fetches a leaf SKILL.md directly (e.g. from search results)
lands with no indication of where the page sits in the tree or how to get
back to the map. This walks public/**/SKILL.md, and for every skill nested
under a hub (depth >= 1) inserts a one-line breadcrumb right after the
frontmatter, linking up through each ancestor hub to the root llms.txt map.

Top-level skills (depth 0) are skipped: they're already one hop from the
root map, so a breadcrumb would add nothing.

Reuses generate_llms_txt.py's frontmatter parsing and title lookup, and
make_links_absolute.py's site-URL resolution, so all three scripts agree on
what the site's base URL and root title are.
"""

import os
import sys

from generate_llms_txt import parse_frontmatter, title_and_blurb
from make_links_absolute import _site_url


def collect_names(public_dir):
    """Return {segments_tuple: (name, url)} for every SKILL.md under public_dir."""
    base_url = _site_url()
    names = {}
    for root, _dirs, files in os.walk(public_dir):
        if "SKILL.md" not in files:
            continue
        rel_dir = os.path.relpath(root, public_dir)
        if rel_dir == os.curdir:
            continue
        filepath = os.path.join(root, "SKILL.md")
        with open(filepath) as f:
            fm = parse_frontmatter(f.read())
        segments = tuple(rel_dir.split(os.sep))
        name = fm.get("name") or segments[-1]
        url = f"{base_url}/{rel_dir.replace(os.sep, '/')}/SKILL.md"
        names[segments] = (name, url)
    return names


def build_breadcrumb(segments, names, root_title, root_url):
    """Render 'Root › ancestor › ... › leaf' with every ancestor linked."""
    crumbs = [f"[{root_title}]({root_url})"]
    for depth in range(1, len(segments)):
        ancestor = segments[:depth]
        name, url = names[ancestor]
        crumbs.append(f"[{name}]({url})")
    leaf_name, _leaf_url = names[segments]
    crumbs.append(leaf_name)
    return " › ".join(crumbs)


def inject(filepath, breadcrumb):
    with open(filepath) as f:
        content = f.read()
    if not content.startswith("---"):
        return False
    end = content.find("---", 3)
    if end == -1:
        return False
    end += 3
    new_content = content[:end] + f"\n\n{breadcrumb}\n\n" + content[end:].lstrip("\n")
    with open(filepath, "w") as f:
        f.write(new_content)
    return True


def run(public_dir):
    base_url = _site_url()
    root_title, _blurb = title_and_blurb(public_dir)
    root_url = f"{base_url}/llms.txt"
    names = collect_names(public_dir)

    injected = 0
    for segments in names:
        if len(segments) < 2:
            continue
        breadcrumb = build_breadcrumb(segments, names, root_title, root_url)
        filepath = os.path.join(public_dir, *segments, "SKILL.md")
        if inject(filepath, breadcrumb):
            injected += 1

    print(f"Breadcrumbs injected into {injected} nested skill page(s)")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "public")
