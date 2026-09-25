#!/usr/bin/env python3
"""Tests hooks/handoff-command.sh. Run by handoff-command.test.sh.

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
tmp = tempfile.mkdtemp(prefix="handoff-command.")


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


def transcript(entries):
    path = os.path.join(tmp, "t%d.jsonl" % len(os.listdir(tmp)))
    with open(path, "w") as fh:
        for kind, content, *meta in entries:
            entry = {"type": kind, "message": {"content": content}}
            if meta:
                entry["isMeta"] = True
            fh.write(json.dumps(entry) + "\n")
    return path


def said(text):
    return ("assistant", [{"type": "text", "text": text}])


# The incident behind the rule: a 209-character `gh api` whose tail was a
# scratchpad path. Copied as three lines, the shell ran `gh api` without its
# --input value and then tried to execute the JSON file.
incident = ("! gh api repos/o/r/pulls/60117/reviews --method POST --input "
            "/private/tmp/claude-502/-Users-x-src-retail/12a9876b-42e5-465f-"
            "ac24-8a43d17a93df/scratchpad/review.json")
check("the incident command blocks", "block", verdict("Run this:\n\n" + incident))
check("a short hand-off is quiet", "quiet", verdict("Run `! gh auth login` first."))
check("a reply with no hand-off is quiet", "quiet", verdict("Done. Tests pass."))

# The boundary. 100 characters fit; 101 do not.
at = "! echo " + "x" * 93
check("exactly 100 characters is quiet", "quiet", verdict(at))
check("101 characters blocks", "block", verdict(at + "x"))

check("a long inline span blocks", "block",
      verdict("Then run `" + incident + "` and tell me."))
check("a `\\` continuation blocks even when short", "block",
      verdict("```\n! gh api repos/o/r \\\n  --input f.json\n```"))
check("an unfenced `\\` continuation blocks", "block",
      verdict("Run:\n! gh api repos/o/r \\\n  --input f.json"))
check("a second line in the hand-off's code block blocks", "block",
      verdict("```\n! cd /tmp/x\nmake install\n```"))
check("a second line in a ~~~ block blocks", "block",
      verdict("~~~\n! cd /tmp/x\nmake install\n~~~"))
check("a one-line ~~~ hand-off is quiet", "quiet",
      verdict("~~~\n! bash /tmp/claude/fix.sh\n~~~"))
check("a ``` line inside ~~~ does not close it", "block",
      verdict("~~~\n! cd /tmp/x\n```\nmake install\n~~~"))
check("a second line in an unclosed code block blocks", "block",
      verdict("```\n! cd /tmp/x\nmake install"))
check("a one-line fenced hand-off is quiet", "quiet",
      verdict("```\n! bash /tmp/claude/fix.sh\n```"))
check("a fenced block with no hand-off is quiet", "quiet",
      verdict("```\n" + "y" * 150 + "\nsecond line\n```"))
check("a line that only mentions `!` is quiet", "quiet",
      verdict("Prefix with ! to run it; " + "z" * 120))

# The loop guard. On the continuation a block forces, stop_hook_active is true,
# and a re-issued command that still breaks the rule must not block again.
check("stop_hook_active silences it", "quiet",
      verdict(incident, stop_hook_active=True))

# The transcript path, for a payload with no last_assistant_message. Only the
# turn that just ended counts: a long hand-off from an earlier turn was already
# reported then. A tool result is a user entry too, and must not end the turn.
old = transcript([
    ("user", "first prompt"), said(incident),
    ("user", "second prompt"), said("All short here."),
])
check("an earlier turn's hand-off is quiet", "quiet",
      fire({"hook_event_name": "Stop", "stop_hook_active": False,
            "transcript_path": old})[1] and "block" or "quiet")
cur = transcript([
    ("user", "prompt"), said("Checking."),
    ("user", [{"type": "tool_result", "content": "x"}]), said(incident),
])
check("a hand-off after a tool result blocks", "block",
      fire({"hook_event_name": "Stop", "stop_hook_active": False,
            "transcript_path": cur})[1] and "block" or "quiet")
meta = transcript([
    ("user", "prompt"), said(incident),
    ("user", "Another Claude session sent a message: ...", True), said("Done."),
])
check("a mid-turn isMeta entry does not end the turn", "block",
      fire({"hook_event_name": "Stop", "stop_hook_active": False,
            "transcript_path": meta})[1] and "block" or "quiet")
check("a missing transcript is quiet", (0, None),
      fire({"hook_event_name": "Stop", "transcript_path": os.path.join(tmp, "no")}))
check("an unparsable payload is quiet", (0, None), fire("not json"))

code, body = fire({"hook_event_name": "Stop", "last_assistant_message": incident})
check("the block reason names the rule", True,
      "A command you hand me to run" in (body or {}).get("reason", ""))
check("the block carries a message for the user", True,
      bool((body or {}).get("systemMessage")))

# Registration. A hook file nobody registers is a check that never runs.
with open(os.path.join(root, "hooks", "hooks.json")) as fh:
    registered = json.load(fh)["hooks"].get("Stop", [])
commands = [h.get("command", "") for g in registered for h in g.get("hooks", [])]
check("hooks.json registers it on Stop", True,
      any(c.endswith("/hooks/handoff-command.sh") for c in commands))

# A wrapper whose program is gone must still exit 0 and say nothing: a Stop
# hook that failed closed would hold every turn in every session open.
lone_dir = tempfile.mkdtemp(prefix="handoff-command-lone.")
lone = os.path.join(lone_dir, "handoff-command.sh")
shutil.copy(hook, lone)
check("a wrapper with no program is quiet", (0, None),
      fire({"hook_event_name": "Stop", "last_assistant_message": incident}, lone))
shutil.rmtree(lone_dir, ignore_errors=True)
shutil.rmtree(tmp, ignore_errors=True)

print("%d failures" % fails)
sys.exit(1 if fails else 0)
