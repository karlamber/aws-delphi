#!/usr/bin/env python3
"""Print whether a saved Terragrunt plan has changes.

The first line is "drift" or "clean". The second line is a one-line total
of the Plan summaries Terraform printed for each unit.
"""

import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
plans = re.findall(
    r"Plan: (\d+) to add, (\d+) to change, (\d+) to destroy",
    text,
)
added = changed = destroyed = 0
for add, change, destroy in plans:
    added += int(add)
    changed += int(change)
    destroyed += int(destroy)

status = "drift" if added or changed or destroyed else "clean"
print(status)
print(
    f"{added} to add, {changed} to change, {destroyed} to destroy "
    f"across {len(plans)} unit plan summaries."
)
