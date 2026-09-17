#!/usr/bin/env bash
# PreToolUse hook on Write and Edit: when a session is about to write a file
# under a dev_docs/ directory, put the layout's name in front of it before the
# tool call runs.
#
# Why a hook and not a skill. The obvious shape was a skill carrying
# `paths: dev_docs/**`, and it does not work. Two independent measurements
# against Claude Code 2.1.274 found the field inert for a PLUGIN-shipped skill:
# plugin skills load through getPluginSkills, while the conditional split that
# reads `paths:` runs in the skill-directory loader, whose sources are managed,
# user, synced, project and additional. The debug log for a plugin session
# carries "Loaded N skills from plugin agent-guidance" and no "conditional
# skills stored" line. Where the field does work, it is a restriction rather
# than a trigger: the skill is withheld until a matching path is touched, and
# activation lands AFTER the write that triggered it, which is the wrong side
# of the one event this guidance exists for.
# `dev_docs/research/2026-09-16-paths-frontmatter-on-plugin-skills.md`
# is the measurement.
#
# A PreToolUse hook has neither problem. It is harness-driven, so no judgment
# decides whether it fires; it runs BEFORE the tool call, so the layout is in
# context while the file is still being written rather than after; and a session
# that never touches the directory pays one process spawn per file edit and
# nothing else: no tokens, no context.
#
# It emits a pointer, never the layout itself. dev_docs_layout.md is ~2,400
# tokens and a second copy here would drift from the file the checker names in
# its own failure output.
#
# Once per session, not once per write. A hook fires on every matching tool
# call, and a plan that writes nine records under dev_docs/ would otherwise pay
# for nine copies of the same paragraph. The marker file is keyed on the
# session id so a second session in the same repo still gets it.
#
# The marker lands in /tmp/claude in practice, not in the payload's
# scratchpad_dir. The hooks reference documents that field on the PreToolUse
# payload, and a live probe against 2.1.274 did not receive it: the marker for
# session f2761851 appeared under /tmp/claude, which is the fallback. So the
# fallback is the ordinary path and scratchpad_dir is the optimisation, which is
# the reverse of how it reads. The cost is that a zero-byte marker per session
# accumulates in /tmp/claude, where nothing prunes it.
#
# Never blocks. `permissionDecision: deny` was the alternative and is wrong
# here: the layout is guidance, not a safety rule, and the checker
# (scripts/dev-docs-layout.py) is the enforcement tier that can afford to say
# no. A hook that denied a write would also deny the write that FIXES a layout
# violation.
#
# Exit 0 on every path, including a malformed payload. A PreToolUse hook that
# exits nonzero is a blocked tool call, and failing a session's write because
# this script could not parse its own input would be a far worse outcome than
# silently not offering a pointer.
set -uo pipefail

payload="$(cat)"

PAYLOAD="$payload" GUIDANCE_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}" python3 -c '
import json, os, pathlib, sys

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
' 2>/dev/null

exit 0
