#!/usr/bin/env python3
"""Tests for make_links_absolute.py"""

import os
import tempfile
import unittest

from make_links_absolute import BASE_URL, make_absolute, run


class TestMakeAbsolute(unittest.TestCase):
    def test_root_level_relative_link(self):
        url = make_absolute("public/index.md", "qdrant-scaling/SKILL.md", "public")
        self.assertEqual(url, f"{BASE_URL}/qdrant-scaling/SKILL.md")

    def test_nested_relative_link(self):
        url = make_absolute(
            "public/qdrant-scaling/SKILL.md", "scaling-data-volume/SKILL.md", "public"
        )
        self.assertEqual(url, f"{BASE_URL}/qdrant-scaling/scaling-data-volume/SKILL.md")

    def test_parent_traversal(self):
        url = make_absolute(
            "public/qdrant-scaling/minimize-latency/SKILL.md",
            "../scaling-data-volume/vertical-scaling/SKILL.md",
            "public",
        )
        self.assertEqual(
            url,
            f"{BASE_URL}/qdrant-scaling/scaling-data-volume/vertical-scaling/SKILL.md",
        )

    def test_https_link_unchanged(self):
        original = "https://example.com/docs"
        self.assertEqual(make_absolute("public/foo/SKILL.md", original, "public"), original)

    def test_http_link_unchanged(self):
        original = "http://example.com/docs"
        self.assertEqual(make_absolute("public/foo/SKILL.md", original, "public"), original)

    def test_root_relative_link_absolutized(self):
        url = make_absolute("public/foo/SKILL.md", "/md/documentation/something/", "public")
        self.assertEqual(url, f"{BASE_URL}/md/documentation/something/")

    def test_root_relative_link_preserves_query(self):
        url = make_absolute("public/foo/SKILL.md", "/md/collections/?s=aliases", "public")
        self.assertEqual(url, f"{BASE_URL}/md/collections/?s=aliases")

    def test_anchor_unchanged(self):
        original = "#section-heading"
        self.assertEqual(make_absolute("public/foo/SKILL.md", original, "public"), original)

    def test_mailto_unchanged(self):
        original = "mailto:support@qdrant.tech"
        self.assertEqual(make_absolute("public/foo/SKILL.md", original, "public"), original)


class TestRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp)

    def write(self, rel_path, content):
        path = os.path.join(self.tmp, rel_path)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(content)
        return path

    def read(self, rel_path):
        with open(os.path.join(self.tmp, rel_path)) as f:
            return f.read()

    def test_relative_links_converted(self):
        self.write(
            "qdrant-scaling/SKILL.md",
            "See [Data Volume](scaling-data-volume/SKILL.md) for details.\n",
        )
        run(self.tmp)
        self.assertIn(
            f"[Data Volume]({BASE_URL}/qdrant-scaling/scaling-data-volume/SKILL.md)",
            self.read("qdrant-scaling/SKILL.md"),
        )

    def test_absolute_links_not_changed(self):
        content = "See [Docs](https://qdrant.tech/docs) for info.\n"
        self.write("qdrant-scaling/SKILL.md", content)
        run(self.tmp)
        self.assertEqual(self.read("qdrant-scaling/SKILL.md"), content)

    def test_root_relative_links_absolutized(self):
        self.write("foo/SKILL.md", "See [Docs](/md/documentation/something/) for info.\n")
        run(self.tmp)
        self.assertIn(
            f"[Docs]({BASE_URL}/md/documentation/something/)",
            self.read("foo/SKILL.md"),
        )

    def test_mixed_links_in_one_file(self):
        self.write(
            "foo/SKILL.md",
            "[Relative](bar/SKILL.md) and [Absolute](https://example.com) and [Root](/md/x).\n",
        )
        run(self.tmp)
        result = self.read("foo/SKILL.md")
        self.assertIn(f"[Relative]({BASE_URL}/foo/bar/SKILL.md)", result)
        self.assertIn("[Absolute](https://example.com)", result)
        self.assertIn(f"[Root]({BASE_URL}/md/x)", result)

    def test_non_md_file_untouched(self):
        self.write("foo/config.json", '{"link": "bar/baz.md"}\n')
        run(self.tmp)
        self.assertEqual(self.read("foo/config.json"), '{"link": "bar/baz.md"}\n')

    def test_parent_traversal_in_nested_file(self):
        self.write(
            "qdrant-scaling/minimize-latency/SKILL.md",
            "See [Vertical](../scaling-data-volume/vertical-scaling/SKILL.md).\n",
        )
        run(self.tmp)
        self.assertIn(
            f"[Vertical]({BASE_URL}/qdrant-scaling/scaling-data-volume/vertical-scaling/SKILL.md)",
            self.read("qdrant-scaling/minimize-latency/SKILL.md"),
        )

    def test_index_at_root_level(self):
        self.write(
            "index.md",
            "- [Scaling](qdrant-scaling/SKILL.md)\n- [Monitoring](qdrant-monitoring/SKILL.md)\n",
        )
        run(self.tmp)
        result = self.read("index.md")
        self.assertIn(f"[Scaling]({BASE_URL}/qdrant-scaling/SKILL.md)", result)
        self.assertIn(f"[Monitoring]({BASE_URL}/qdrant-monitoring/SKILL.md)", result)


if __name__ == "__main__":
    unittest.main()
