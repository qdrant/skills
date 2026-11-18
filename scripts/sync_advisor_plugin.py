#!/usr/bin/env python3
"""Keep the qdrant-advisor plugin's SKILL.md in sync with meta/qdrant-advisor.

meta/qdrant-advisor/SKILL.md is the source of truth. The plugin needs a real
copy because the Claude plugin directory rejects symlinks and installs only the
plugin folder.

Usage:
    python3 scripts/sync_advisor_plugin.py          # update the plugin copy
    python3 scripts/sync_advisor_plugin.py --check  # fail if the copy is stale
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "meta" / "qdrant-advisor" / "SKILL.md"
TARGET = ROOT / "plugins" / "qdrant-advisor" / "skills" / "qdrant-advisor" / "SKILL.md"


def main() -> int:
    in_sync = TARGET.is_file() and TARGET.read_bytes() == SOURCE.read_bytes()
    if "--check" in sys.argv[1:]:
        if in_sync:
            print("qdrant-advisor plugin skill is in sync")
            return 0
        print(
            f"{TARGET.relative_to(ROOT)} is out of sync with {SOURCE.relative_to(ROOT)}.\n"
            "Run: python3 scripts/sync_advisor_plugin.py",
            file=sys.stderr,
        )
        return 1
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE, TARGET)
    print(f"synced {SOURCE.relative_to(ROOT)} -> {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
