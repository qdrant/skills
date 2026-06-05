#!/usr/bin/env python3
"""Convert relative markdown links to absolute URLs for the deployed site."""

import os
import re
from urllib.parse import urljoin, urlsplit

def _site_url():
    """Resolve the site's base URL from Netlify's build environment.

    On production we want the custom domain, which Netlify exposes via URL —
    DEPLOY_PRIME_URL there is the branch permalink (e.g.
    https://main--qdrant-skills.netlify.app), not skills.qdrant.tech. On deploy
    previews and branch deploys we prefer DEPLOY_PRIME_URL so links stay self
    consistent with the deploy being viewed. Fall back to the production domain
    for local builds.
    """
    if os.environ.get("CONTEXT") == "production":
        url = os.environ.get("URL")
    else:
        url = os.environ.get("DEPLOY_PRIME_URL") or os.environ.get("URL")
    return (url or "https://skills.qdrant.tech").rstrip("/")


BASE_URL = _site_url()
PUBLIC_DIR = "public"

LINK_RE = re.compile(r'\[([^\]]*)\]\(([^)]+)\)')


def make_absolute(filepath, url, public_dir):
    # Leave in-page anchors and anything carrying a scheme (http, https,
    # mailto, …) untouched. Root-relative ("/…") and directory-relative links
    # are both resolved to an absolute site URL below.
    if url.startswith("#") or urlsplit(url).scheme:
        return url
    # URL path of the file's directory relative to the site root.
    file_dir = os.path.relpath(os.path.dirname(filepath), public_dir)
    base_path = "/" if file_dir == os.curdir else "/" + file_dir.replace(os.sep, "/") + "/"
    # Resolve the link against its directory, then against the site origin. A
    # leading "/" makes urljoin discard base_path, so root-relative links are
    # attached directly to the origin.
    return urljoin(BASE_URL, urljoin(base_path, url))


def run(public_dir):
    for root, _dirs, files in os.walk(public_dir):
        for filename in files:
            if not filename.endswith(".md"):
                continue
            filepath = os.path.join(root, filename)
            with open(filepath) as f:
                content = f.read()
            new_content = LINK_RE.sub(
                lambda m: f"[{m.group(1)}]({make_absolute(filepath, m.group(2), public_dir)})",
                content,
            )
            if new_content != content:
                with open(filepath, "w") as f:
                    f.write(new_content)


if __name__ == "__main__":
    run(PUBLIC_DIR)
