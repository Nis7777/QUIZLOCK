#!/usr/bin/env python3
"""Checks AppStore/metadata.md against App Store Connect character limits."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
text = open(os.path.join(ROOT, "AppStore", "metadata.md"), encoding="utf-8").read()
ok = True
for lang in re.split(r"^## ", text, flags=re.M)[1:]:
    title = lang.splitlines()[0]
    for m in re.finditer(r"^\*\*(.+?)\*\* \((\d+)\)\n(.*?)(?=^\*\*|\Z)", lang, flags=re.M | re.S):
        field, limit, value = m.group(1), int(m.group(2)), m.group(3).strip()
        n = len(value)
        flag = "OK" if n <= limit else "TOO LONG"
        if field.startswith("Keywords") and ", " in value:
            flag = "SPACE AFTER COMMA"
        ok &= flag == "OK"
        print(f"[{title}] {field}: {n}/{limit} {flag}")
sys.exit(0 if ok else 1)
