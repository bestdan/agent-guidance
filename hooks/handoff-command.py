#!/usr/bin/env python3
"""Reports a `! <command>` hand-off that will not survive a copy. Run by
hooks/handoff-command.sh.

Reads the Stop payload from PAYLOAD, finds the text of the turn that just
ended, and writes the hook response on stdout or nothing at all. The wrapper
carries the reasoning; this is the program it runs.
"""

import json
import os
import re
import sys

LIMIT = 100

# An inline code span whose content starts with "! ". A fenced line is handled
# separately, because a fence can hold a continuation the span form cannot.
SPAN = re.compile(r"`(! [^`\n]+)`")


def handoffs(text):
    """Yield (command, reason) for each hand-off in text that breaks the rule."""
    seen = set()
    lines = text.splitlines()
    in_fence = False
    fence_cmd = None
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            if in_fence and fence_cmd is not None:
                cmd, extra = fence_cmd
                if extra:
                    yield cmd, "it spans more than one line of its code block"
            in_fence = not in_fence
            fence_cmd = None
            continue
        if in_fence:
            if fence_cmd is None and stripped.startswith("! "):
                fence_cmd = [stripped, False]
                yield from _check(stripped, seen)
            elif fence_cmd is not None and stripped:
                fence_cmd[1] = True
            continue
        if stripped.startswith("! "):
            yield from _check(stripped, seen)
            continue
        for match in SPAN.finditer(line):
            yield from _check(match.group(1).strip(), seen)


def _check(cmd, seen):
    if cmd in seen:
        return
    seen.add(cmd)
    if cmd.endswith("\\"):
        yield cmd, "it ends in a `\\` continuation"
    elif len(cmd) > LIMIT:
        yield cmd, f"it is {len(cmd)} characters, over the {LIMIT} that fit without wrapping"


def turn_text(hook):
    """The assistant text of the turn that just ended."""
    last = hook.get("last_assistant_message")
    if isinstance(last, str) and last:
        return last
    path = hook.get("transcript_path")
    if not path:
        return ""
    texts = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                try:
                    entry = json.loads(raw)
                except ValueError:
                    continue
                if entry.get("isSidechain"):
                    continue
                kind = entry.get("type")
                content = (entry.get("message") or {}).get("content")
                if kind == "user" and _is_prompt(content):
                    texts = []
                elif kind == "assistant" and isinstance(content, list):
                    texts.extend(
                        c.get("text", "") for c in content
                        if isinstance(c, dict) and c.get("type") == "text"
                    )
    except OSError:
        return ""
    return "\n".join(texts)


def _is_prompt(content):
    """A user entry that starts a turn, rather than one carrying a tool result."""
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(
            isinstance(c, dict) and c.get("type") == "tool_result" for c in content
        )
    return False


def main():
    try:
        hook = json.loads(os.environ["PAYLOAD"])
    except (ValueError, KeyError):
        return
    if hook.get("stop_hook_active"):
        return
    findings = list(handoffs(turn_text(hook)))
    if not findings:
        return
    listed = "\n".join(
        f"- {reason}: {cmd[:80]}{'...' if len(cmd) > 80 else ''}"
        for cmd, reason in findings
    )
    reason = (
        "A command you handed the user will not survive a copy out of the "
        "terminal:\n" + listed + "\n"
        "Some terminals keep a soft wrap as a real newline in the copy, so the "
        "shell runs each fragment as its own command. Re-issue each one in a "
        "form that fits on one line: move a long path to a short fixed one, or "
        "write the command to a script at a short path and hand over "
        "`! bash <that path>`. Say that the earlier version is replaced. The "
        "rule is the `A command you hand me to run` bullet in portable.md."
    )
    json.dump({
        "decision": "block",
        "reason": reason,
        "systemMessage": "A hand-off command in that reply may break when "
        "copied; a corrected one follows.",
    }, sys.stdout)


main()
