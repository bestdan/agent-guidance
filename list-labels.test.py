#!/usr/bin/env python3
"""Tests hooks/list-labels.sh. Run by list-labels.test.sh.

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
tmp = tempfile.mkdtemp(prefix="list-labels.")


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


# The incident behind the rule: four numbered steps, one of them holding
# lettered options, then three numbered decisions. "Do 2" named a step and a
# decision at once.
incident = """1. Move the valid parts into #1294
  - The python-multipart minimum from #1186.
  - A "Carried forward" section in the report.
2. Close #1227, #1207, #1186 and #1167.
3. Fix the process. Options:
  - (a) Recommended: close any open nightly PR.
  - (b) Reuse one long-running branch.
4. Smaller prompt fixes.

Decisions for you

1. Should I do steps 1 and 2 now?
2. For step 3, option (a) or (b)?
3. Should I file Linear tickets?"""
check("the incident reply blocks", "block", verdict(incident))
fixed = incident.replace("\n1. Should", "\nQ1. Should").replace(
    "\n2. For", "\nQ2. For").replace("\n3. Should", "\nQ3. Should")
check("the incident with Q-prefixed decisions is quiet", "quiet", verdict(fixed))
check("bold prefixed labels are quiet", "quiet",
      verdict("1. a\n2. b\n\n**Q1.** c\n**Q2.** d"))

check("one numbered list is quiet", "quiet", verdict("1. a\n2. b\n3. c"))
check("a reply with no list is quiet", "quiet", verdict("Done. Tests pass."))
check("a list continued after a paragraph is quiet", "quiet",
      verdict("1. a\n2. b\n\nMeanwhile:\n\n3. c\n4. d"))
check("two numbered lists with no shared number are quiet", "quiet",
      verdict("1. a\n2. b\n\nThen:\n\n3. c"))
check("a numbered list restarting at 1 blocks", "block",
      verdict("1. a\n2. b\n\nThen:\n\n1. c"))
check("a `1)` list after a `1.` list blocks", "block",
      verdict("1. a\n\nThen:\n\n1) c"))
check("bold numbers count", "block",
      verdict("**1.** a\n\nThen:\n\n**1.** c"))
check("lists in a blockquote count", "block",
      verdict("> 1. a\n\nThen:\n\n1. c"))
check("a numbered list inside a numbered item blocks", "block",
      verdict("1. a\n   1. sub\n   2. sub\n2. b"))
check("a numbered list under a bullet under a numbered item blocks", "block",
      verdict("1. a\n   - x\n     1. sub\n2. b"))
check("numbered lists under separate bullets share a number and block", "block",
      verdict("- X\n  1. a\n- Y\n  1. b"))
check("a list under a bullet then a list at the margin blocks", "block",
      verdict("- theme:\n  1. a\n  2. b\n\n1. question"))
check("a list under a bullet then a list continuing its count is quiet", "quiet",
      verdict("- theme:\n  1. a\n  2. b\n\n3. question"))
check("lettered items inside a numbered item are quiet", "quiet",
      verdict("1. a\n   a. sub\n   b. sub\n2. b\n   a. sub"))
check("bullets inside numbered items are quiet", "quiet",
      verdict("1. a\n   - x\n2. b\n   - y"))
check("a numbered list in a code block does not count", "quiet",
      verdict("1. a\n\n```\n1. not a list\n```"))
check("a numbered list in a ~~~ block does not count", "quiet",
      verdict("1. a\n\n~~~\n1. not a list\n```\n1. still not\n~~~"))
check("a version number at the margin is not an item", "quiet",
      verdict("1. a\n\n1.2 is the version."))

# The loop guard. On the continuation a block forces, stop_hook_active is true,
# and a relabelled reply that still repeats a number must not block again.
check("stop_hook_active silences it", "quiet",
      verdict(incident, stop_hook_active=True))

# The transcript path, for a payload with no last_assistant_message.
# handoff-command.test.py covers which turn it reads; this checks the wiring.
path = os.path.join(tmp, "t.jsonl")
with open(path, "w") as fh:
    fh.write(json.dumps({"type": "user", "message": {"content": "go"}}) + "\n")
    fh.write(json.dumps({"type": "assistant", "message": {
        "content": [{"type": "text", "text": incident}]}}) + "\n")
check("a transcript reply blocks", "block",
      fire({"hook_event_name": "Stop", "stop_hook_active": False,
            "transcript_path": path})[1] and "block" or "quiet")
check("an unparsable payload is quiet", (0, None), fire("not json"))

code, body = fire({"hook_event_name": "Stop", "last_assistant_message": incident})
check("the block reason names the rule", True,
      "Give each list label in a reply one meaning" in (body or {}).get("reason", ""))
with open(os.path.join(root, "portable.md")) as fh:
    check("portable.md carries the rule the reason names", True,
          "Give each list label in a reply one meaning" in fh.read())
check("the block carries a message for the user", True,
      bool((body or {}).get("systemMessage")))

# Registration. A hook file nobody registers is a check that never runs.
with open(os.path.join(root, "hooks", "hooks.json")) as fh:
    registered = json.load(fh)["hooks"].get("Stop", [])
commands = [h.get("command", "") for g in registered for h in g.get("hooks", [])]
check("hooks.json registers it on Stop", True,
      any(c.endswith("/hooks/list-labels.sh") for c in commands))

# A wrapper whose program is gone must still exit 0 and say nothing: a Stop
# hook that failed closed would hold every turn in every session open.
lone_dir = tempfile.mkdtemp(prefix="list-labels-lone.")
lone = os.path.join(lone_dir, "list-labels.sh")
shutil.copy(hook, lone)
check("a wrapper with no program is quiet", (0, None),
      fire({"hook_event_name": "Stop", "last_assistant_message": incident}, lone))
shutil.rmtree(lone_dir, ignore_errors=True)
shutil.rmtree(tmp, ignore_errors=True)

print("%d failures" % fails)
sys.exit(1 if fails else 0)
