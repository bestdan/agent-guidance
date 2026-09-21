#!/usr/bin/env python3
"""Emits the dev_docs/ layout pointer. Run by hooks/dev-docs-context.sh.

Reads the PreToolUse payload from PAYLOAD and the plugin root from
GUIDANCE_ROOT, both set by the wrapper, and writes the hook response on
stdout or nothing at all.

Why this is a file rather than a `python3 -c` argument, and what the wrapper
keeps: `dev_docs/decisions/2026-09-20-hook-python-lives-in-a-file-beside-the-shell.md`.
The wrapper carries the reasoning for the behaviour below; it is the file a
reader arrives at from hooks.json, and this is the program it runs.
"""

import json
import os
import pathlib
import sys

try:
    hook = json.loads(os.environ["PAYLOAD"])
except (ValueError, KeyError):
    sys.exit(0)

path = (hook.get("tool_input") or {}).get("file_path") or ""
if not path:
    sys.exit(0)

# A segment match, not a substring one. "dev_docs" as a substring also matches
# a file called dev_docs_layout.md at a repo root, which is this plugin every
# time someone edits the convention itself -- the one file whose author has
# already read it.
parts = pathlib.PurePath(path).parts
if "dev_docs" not in parts or parts[-1] == "dev_docs":
    sys.exit(0)

# Once per session. scratchpad_dir is session-scoped and the harness makes it;
# /tmp/claude is the fallback for a payload that predates the field, and is on
# the sandbox write allowlist in both sandbox modes.
scratch = hook.get("scratchpad_dir") or "/tmp/claude"
session = hook.get("session_id") or "unknown"
marker = pathlib.Path(scratch) / (".dev-docs-context-" + str(session))
try:
    marker.parent.mkdir(parents=True, exist_ok=True)
    if marker.exists():
        sys.exit(0)
    marker.touch()
except OSError:
    # An unwritable marker directory means the pointer repeats rather than
    # never arriving. Repetition is the cheaper failure.
    pass

root = os.environ["GUIDANCE_ROOT"]
context = (
    "This writes a file under dev_docs/. Before continuing, read "
    + root + "/dev_docs_layout.md, then the dev_docs/README.md at the repo "
    "root, then the README.md of the directory you are writing into. The "
    "layout fixes which directory holds what, and the naming rule that decides "
    "the filename: a date in the name means a record that may go stale, no "
    "date means a live file kept current. Each directory README carries the "
    "front matter and template for its own files. The dev_docs/README.md at "
    "the repo root lists the exceptions that repo makes, which win over both. "
    "The check that enforces this is " + root + "/scripts/dev-docs-layout.py."
)

json.dump({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": context,
    }
}, sys.stdout)
