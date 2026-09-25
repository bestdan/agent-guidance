#!/usr/bin/env python3
"""Counts `! <command>` hand-off lines in Claude Code transcripts, by length.

Run: python3 transcript-scan.py
Needs: python3 only. Reads ~/.claude/projects/*/*.jsonl, the main-session
transcripts, and looks at assistant text blocks alone. A line counts when,
stripped of whitespace and backticks, it starts with "! ".
"""

import collections
import glob
import json
import os

root = os.path.expanduser("~/.claude/projects")
files = glob.glob(f"{root}/*/*.jsonl")
blocks = hits = cont = 0
buckets = collections.Counter()
examples = []
for f in files:
    try:
        fh = open(f, encoding="utf-8", errors="replace")
    except OSError:
        continue
    with fh:
        for line in fh:
            try:
                o = json.loads(line)
            except Exception:
                continue
            if o.get("type") != "assistant":
                continue
            for c in (o.get("message") or {}).get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "text":
                    continue
                blocks += 1
                for raw in c["text"].splitlines():
                    s = raw.strip().strip("`").strip()
                    if not s.startswith("! "):
                        continue
                    hits += 1
                    n = len(s)
                    if n <= 80:
                        buckets["<=80"] += 1
                    elif n <= 100:
                        buckets["81-100"] += 1
                    elif n <= 150:
                        buckets["101-150"] += 1
                    else:
                        buckets[">150"] += 1
                    if s.endswith("\\"):
                        cont += 1
                    if n > 100 and len(examples) < 10:
                        examples.append((n, s[:170]))
print("files", len(files), "text blocks", blocks, "bang lines", hits)
print(dict(buckets), "continuations", cont)
for e in examples:
    print(e)
