#!/usr/bin/env python3
"""Tests hooks/handoff-inline.sh. Run by handoff-inline.test.sh.

Reads the hook under test from HOOK and the repo root from ROOT, both set by
the wrapper, and prints one ok/FAIL line per case plus a failure count.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

hook = os.environ["HOOK"]
root = os.environ["ROOT"]
fails = 0
tmp = tempfile.mkdtemp(prefix="handoff-inline.")


def check(name, want, got):
    global fails
    if want == got:
        print("ok   " + name)
    else:
        fails += 1
        print("FAIL %s: want %r, got %r" % (name, want, got))


def fire(payload, script=hook):
    """Run the hook on one payload; return (exit code, parsed stdout or None)."""
    raw = payload if isinstance(payload, str) else json.dumps(payload)
    proc = subprocess.run(
        ["bash", script], input=raw, capture_output=True, text=True
    )
    out = proc.stdout.strip()
    return proc.returncode, (json.loads(out) if out else None)


def verdict(text, **extra):
    """"block" or "quiet" for a reply carried in last_assistant_message."""
    payload = {"hook_event_name": "Stop", "stop_hook_active": False,
               "last_assistant_message": text}
    payload.update(extra)
    code, body = fire(payload)
    if code != 0:
        return "exit%d" % code
    if body is None:
        return "quiet"
    ok = body.get("decision") == "block" and body.get("reason")
    return "block" if ok else "malformed"


# The incident behind the rule: a prompt for another agent pasted as a nested
# blockquote. A copy of it carries every `>` and every indent.
incident = "\n".join([
    "Here is the prompt for the other agent:",
    "",
    "> Pick up the kindle chapter in ai-scifi.",
    ">",
    "> - Enter the worktree at $HOME/src/worktrees/ai-scifi/kindle",
    ">   - run `just build` first",
    "> - Read stories/kindle/outline.md",
    "> - Draft scene 3 from the notes in the outline",
    "> - Open a draft PR when the scene reads clean",
])
check("the incident blockquote blocks", "block", verdict(incident))

fenced = "\n".join([
    "```",
    "You are picking up the kindle chapter.",
    "Enter the worktree at $HOME/src/worktrees/ai-scifi/kindle.",
    "Read stories/kindle/outline.md.",
    "Draft scene 3 and open a draft PR.",
    "```",
])
check("a long fenced prompt blocks", "block", verdict(fenced))
check("an unclosed long fenced prompt blocks", "block",
      verdict(fenced.rsplit("\n", 1)[0]))
check("a ~~~ fenced prompt blocks", "block",
      verdict(fenced.replace("```", "~~~")))

# The shape the rule asks for.
check("the one-line pointer is quiet", "quiet", verdict(
    "Handoff written.\n\n```\n"
    "Read /home/u/handoffs/2026-10-14-kindle.md and follow it.\n```"))
check("a one-line quoted pointer is quiet", "quiet", verdict(
    "> Read /home/u/handoffs/2026-10-14-kindle.md and follow it."))

# The boundary. Three non-blank lines fit; four do not.
three = "```\npick up the work\nline two\n\nline three\n```"
check("three lines with a cue are quiet", "quiet", verdict(three))
check("four lines with a cue block", "block",
      verdict(three.replace("line three", "line three\nline four")))

# Long blocks with no cue are ordinary content.
check("a long code block with no cue is quiet", "quiet",
      verdict("```\n" + "\n".join("line %d" % i for i in range(20)) + "\n```"))
check("a long quote with no cue is quiet", "quiet",
      verdict("\n".join("> quoted rule line %d" % i for i in range(8))))
check("a cue outside any block is quiet", "quiet",
      verdict("Pick up where we left off.\n\n```\na\nb\nc\nd\ne\n```"))
check("a reply with no blocks is quiet", "quiet", verdict("Done. Tests pass."))

# A quote ends at the first line without `>`, so two short quotes do not add
# up to one long one.
check("two short quotes split by prose are quiet", "quiet", verdict(
    "> pick up a\n> b\n\nprose\n\n> c\n> d"))
# A `>` line inside a fence is content, not a quote.
check("a > line inside a fence does not open a quote", "quiet",
      verdict("```\n> pick up\n```\n> a\n> b"))

check("stop_hook_active silences it", "quiet",
      verdict(incident, stop_hook_active=True))

code, body = fire({"hook_event_name": "Stop", "last_assistant_message": incident})
check("the block reason names the rule", True,
      "A handoff is a file" in (body or {}).get("reason", ""))
check("the block carries a message for the user", True,
      bool((body or {}).get("systemMessage")))
check("an unparsable payload is quiet", (0, None), fire("not json"))

# Registration. A hook file nobody registers is a check that never runs.
with open(os.path.join(root, "hooks", "hooks.json")) as fh:
    registered = json.load(fh)["hooks"].get("Stop", [])
commands = [h.get("command", "") for g in registered for h in g.get("hooks", [])]
check("hooks.json registers it on Stop", True,
      any(c.endswith("/hooks/handoff-inline.sh") for c in commands))

# A wrapper whose program is gone must still exit 0 and say nothing: a Stop
# hook that failed closed would hold every turn in every session open.
lone_dir = tempfile.mkdtemp(prefix="handoff-inline-lone.")
lone = os.path.join(lone_dir, "handoff-inline.sh")
shutil.copy(hook, lone)
check("a wrapper with no program is quiet", (0, None),
      fire({"hook_event_name": "Stop", "last_assistant_message": incident}, lone))
shutil.rmtree(lone_dir, ignore_errors=True)
shutil.rmtree(tmp, ignore_errors=True)

print("%d failures" % fails)
sys.exit(1 if fails else 0)
