#!/usr/bin/env python3
"""Tests for generate_llms_txt.py"""

import os
import tempfile
import unittest

from generate_llms_txt import collect_skills


def write_skill(public_dir, rel_dir, name):
    skill_dir = os.path.join(public_dir, rel_dir)
    os.makedirs(skill_dir, exist_ok=True)
    with open(os.path.join(skill_dir, "SKILL.md"), "w") as f:
        f.write(f'---\nname: {name}\ndescription: "{name} description"\n---\n\nBody\n')


class TestCollectSkills(unittest.TestCase):
    def depths(self, public_dir):
        return {name: depth for depth, name, _url, _desc in collect_skills(public_dir)}

    def test_sub_skills_nest_under_their_hub(self):
        with tempfile.TemporaryDirectory() as tmp:
            write_skill(tmp, "hub", "hub")
            write_skill(tmp, "hub/leaf", "leaf")
            write_skill(tmp, "hub/leaf/deeper", "deeper")
            self.assertEqual(self.depths(tmp), {"hub": 0, "leaf": 1, "deeper": 2})

    def test_container_directory_without_skill_adds_no_depth(self):
        # meta/ has no SKILL.md, so meta/qdrant-advisor has no parent entry to
        # nest under and must be listed at the top level.
        with tempfile.TemporaryDirectory() as tmp:
            write_skill(tmp, "meta/qdrant-advisor", "qdrant-advisor")
            write_skill(tmp, "qdrant-scaling", "qdrant-scaling")
            self.assertEqual(
                self.depths(tmp), {"qdrant-advisor": 0, "qdrant-scaling": 0}
            )


if __name__ == "__main__":
    unittest.main()
