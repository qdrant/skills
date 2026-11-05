#!/usr/bin/env python3
"""Generate the Agent Skills Discovery index for the deployed site.

Writes public/.well-known/agent-skills/index.json in the format of the Agent
Skills Discovery draft (https://github.com/cloudflare/agent-skills-discovery-rfc,
schema 0.2.0), so a client given skills.qdrant.tech can list every skill with
one request.

Each entry's digest is the SHA-256 of the bytes this site serves, so this must
run after every step that rewrites SKILL.md (link rewriting, breadcrumbs).
URLs are path-absolute, which keeps them valid on deploy previews too.
"""

import hashlib
import json
import os
import re
import sys

from generate_llms_txt import parse_frontmatter

SCHEMA = "https://schemas.agentskills.io/discovery/0.2.0/schema.json"
# Spec naming rule: lowercase alphanumerics and single hyphens, 1-64 characters.
NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def collect(public_dir):
    skills, seen, errors = [], set(), []
    for root, _dirs, files in sorted(os.walk(public_dir)):
        rel_dir = os.path.relpath(root, public_dir)
        if "SKILL.md" not in files or rel_dir == os.curdir:
            continue
        rel = f"{rel_dir.replace(os.sep, '/')}/SKILL.md"
        with open(os.path.join(root, "SKILL.md"), "rb") as f:
            raw = f.read()
        fm = parse_frontmatter(raw.decode("utf-8"))
        name, description = fm.get("name", ""), fm.get("description", "")
        if not (NAME.match(name) and len(name) <= 64):
            errors.append(f"{rel}: invalid name {name!r}")
        elif not description or len(description) > 1024:
            errors.append(f"{rel}: description missing or over 1024 characters")
        elif name in seen:
            errors.append(f"{rel}: duplicate name {name!r}")
        else:
            seen.add(name)
            skills.append({
                "name": name,
                "type": "skill-md",
                "description": description,
                "url": f"/{rel}",
                "digest": f"sha256:{hashlib.sha256(raw).hexdigest()}",
            })
    return skills, errors


def run(public_dir):
    skills, errors = collect(public_dir)
    if errors:
        # Fail the build: a skill silently missing from the index is worse
        # than a deploy that keeps the last good site live.
        sys.exit("agent-skills index:\n  " + "\n  ".join(errors))
    out_dir = os.path.join(public_dir, ".well-known", "agent-skills")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "index.json")
    with open(out_path, "w") as f:
        json.dump({"$schema": SCHEMA, "skills": skills}, f, indent=2)
        f.write("\n")
    print(f"Agent skills index generated at {out_path} ({len(skills)} skills)")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "public")
