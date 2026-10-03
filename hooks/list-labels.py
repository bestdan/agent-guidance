#!/usr/bin/env python3
"""Reports a numbered list label that means two things in one reply. Run by
hooks/list-labels.sh.

Reads the Stop payload from PAYLOAD, finds the text of the turn that just
ended, and writes the hook response on stdout or nothing at all. The wrapper
carries the reasoning; this is the program it runs.
"""

import json
import os
import re
import sys

from stop_turn import turn_text

# A list item: indentation, any blockquote markers, then a bullet or a number.
# Bold around the number, `**2.**`, still renders as a label the user answers.
ITEM = re.compile(r"^( *)(?:> ?)*(?:[-*+]|\**(\d{1,3})[.)]\**)\s+\S")
FENCE = re.compile(r"(`{3,}|~{3,})")


def findings(text):
    """Yield one reason for each way the reply's numbers stop naming one item."""
    seen = set()
    restarted = nested = False
    stack = []  # (indent, numbered) for each open item, outermost first
    in_fence = False
    opener = ""
    for line in text.expandtabs(4).splitlines():
        stripped = line.strip()
        marker = FENCE.match(stripped)
        if in_fence:
            if (marker and marker.group(1)[0] == opener[0]
                    and len(marker.group(1)) >= len(opener)
                    and stripped == marker.group(1)):
                in_fence = False
            continue
        if marker:
            in_fence, opener = True, marker.group(1)
            continue
        item = ITEM.match(line)
        if item is None:
            # A paragraph at the margin ends the list; the next list is a new
            # one, and its numbers share the reply with this one's.
            if stripped and not line.startswith(" "):
                stack = []
            continue
        indent, number = len(item.group(1)), item.group(2)
        while stack and stack[-1][0] >= indent:
            stack.pop()
        if number is not None:
            if any(numbered for _, numbered in stack):
                nested = True
            elif not stack:
                if number in seen:
                    restarted = True
                seen.add(number)
        stack.append((indent, number is not None))
    if restarted:
        yield "two numbered lists in the reply share a number"
    if nested:
        yield "a numbered list sits inside a numbered item"


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
    reason = (
        "The user cannot answer that reply by number, because "
        + " and ".join(found) + ".\n"
        "Re-issue the reply so that each label names one item. Number one "
        "list at most. Label a second list (A), (B), (C), and items inside an "
        "item a, b, c, so that `3b` names one item. Say that the earlier "
        "version is replaced. The rule is the `Give each list label in a "
        "reply one meaning` bullet in portable.md."
    )
    json.dump({
        "decision": "block",
        "reason": reason,
        "systemMessage": "That reply reused a list number; a relabelled "
        "version follows, so answer that one.",
    }, sys.stdout)


main()
