#!/usr/bin/env python3
"""Reports a handoff pasted into the reply instead of written to a file. Run by
hooks/handoff-inline.sh.

Reads the Stop payload from PAYLOAD, finds the text of the turn that just
ended, and writes the hook response on stdout or nothing at all. The wrapper
carries the reasoning; this is the program it runs.
"""

import json
import os
import re
import sys

from stop_turn import turn_text

# More lines than this in one block reads as a body, not a pointer. The pointer
# the rule asks for is one line.
MAX_LINES = 3

FENCE = re.compile(r"(`{3,}|~{3,})")
QUOTE = re.compile(r"^\s*>")

# Phrases that address another agent picking up work. A long code block or
# quote without one is ordinary content: a log, a diff, a quoted rule.
CUES = re.compile(
    r"\bpick(?:ing)? (?:it |this |the work )?up\b"
    r"|\bhand(?:ing)?[- ]?off\b"
    r"|\benter(?:ing)? the worktree\b"
    r"|\bEnterWorktree\b"
    r"|\bfollow it\b"
    r"|\b(?:the|a) previous (?:agent|session)\b"
    r"|\byou are (?:continuing|picking up|taking over)\b"
    r"|\byour task is\b",
    re.I,
)


def blocks(text):
    """Yield (kind, lines) for each fenced block and each blockquote in text."""
    in_fence = False
    opener = ""
    body = []
    quote = []
    for line in text.splitlines():
        stripped = line.strip()
        marker = FENCE.match(stripped)
        if in_fence:
            # A block closes only on a run of its opener's character at least
            # as long, with nothing after it, as in copyable-command.py.
            if (marker is not None and marker.group(1)[0] == opener[0]
                    and len(marker.group(1)) >= len(opener)
                    and stripped == marker.group(1)):
                yield "code block", body
                in_fence, body = False, []
            else:
                body.append(line)
            continue
        if QUOTE.match(line):
            quote.append(line)
            continue
        if quote:
            yield "blockquote", quote
            quote = []
        if marker is not None:
            in_fence, opener, body = True, marker.group(1), []
    if quote:
        yield "blockquote", quote
    if in_fence:
        yield "code block", body


def findings(text):
    """Yield (kind, line count) for each block that reads as a pasted handoff."""
    for kind, lines in blocks(text):
        filled = [ln for ln in lines if ln.strip(" >\t")]
        if len(filled) > MAX_LINES and CUES.search("\n".join(lines)):
            yield kind, len(filled)


def main():
    try:
        hook = json.loads(os.environ["PAYLOAD"])
    except (ValueError, KeyError):
        return
    if hook.get("stop_hook_active"):
        return
    found = list(findings(turn_text(hook)))
    if not found:
        return
    listed = "\n".join(f"- a {kind} of {n} lines" for kind, n in found)
    reason = (
        "That reply pasted a handoff for another agent into the terminal:\n"
        + listed + "\n"
        "A copy out of the terminal carries the `>` prefixes and the "
        "indentation, so the prompt reaches the next agent mangled. Write the "
        "handoff to dev_docs/.handoffs/YYYY-MM-DD-<topic>.md by that "
        "directory's README.md, or to /tmp/claude/handoffs/ when the repo has "
        "no .handoffs/ or this session cannot write there. Then re-issue it as "
        "one line in one fenced code block, such as `Read <path> and follow "
        "it.`, and say that the pasted version is replaced. The rule is the "
        "`A handoff is a file` bullet in portable.md; the "
        "agent-guidance:handoff skill carries the steps."
    )
    json.dump({
        "decision": "block",
        "reason": reason,
        "systemMessage": "That reply pasted a handoff into the terminal; "
        "use the file pointer in the follow-up instead.",
    }, sys.stdout)


main()
