#!/usr/bin/env bash
# Tests hooks/gh-body-guard.sh, the PreToolUse hook that refuses a gh --body
# argument the shell would run a command substitution inside.
# Run: bash gh-body-guard.test.sh
#
# Why this suite exists. The guard's two failure directions are both quiet. If
# it stops denying, the thing it prevents is silent by construction --- gh exits
# 0 and posts the substitution's output --- so nothing reports the regression. If
# it starts denying too much, it blocks correct commands, and the obvious fix
# from inside a session is to work around the guard rather than to suspect it.
#
# The cases are the boundaries. Quoting is the entire distinction being drawn
# here, so most of them differ from a neighbour by one quote character.
#
# The payloads are built with json.dumps rather than printf. Every interesting
# command in this file contains backticks, double quotes, single quotes or a
# backslash, and a hand-quoted JSON template mangles those into something that
# still parses --- so a broken case would report a passing guard.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GUARD="$self/hooks/gh-body-guard.sh"
export ROOT="$self"

python3 -c '
import json, os, subprocess, sys

guard = os.environ["GUARD"]
fails = 0


def run(command, *, raw=None):
    """Feed the guard one payload; return "deny", "allow", or "notjson"."""
    if raw is None:
        payload = json.dumps({
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "session_id": "test",
            "tool_input": {"command": command},
        })
    else:
        payload = raw
    proc = subprocess.run(
        ["bash", guard], input=payload, capture_output=True, text=True
    )
    if proc.returncode != 0:
        return "exit%d" % proc.returncode
    out = proc.stdout.strip()
    if not out:
        return "allow"
    try:
        body = json.loads(out)
    except ValueError:
        return "notjson"
    spec = body.get("hookSpecificOutput") or {}
    if spec.get("permissionDecision") == "deny":
        return "deny" if spec.get("permissionDecisionReason") else "deny-noreason"
    return "allow"


def check(desc, want, got):
    global fails
    if want == got:
        print("ok   %s" % desc)
    else:
        print("FAIL %s (want %s, got %s)" % (desc, want, got))
        fails += 1


# --- denied: the shell runs the substitution before gh sees it ---------------

check("double-quoted backtick",
      "deny", run("gh pr comment 1 --body \"see `date` here\""))

check("unquoted $( ",
      "deny", run("gh pr create --title x --body $(cat notes.md)"))

check("--body= joined form",
      "deny", run("gh issue comment 5 --body=\"a `id` b\""))

check("-b shorthand",
      "deny", run("gh pr create -b \"`whoami`\""))

check("double-quoted $( ",
      "deny", run("gh pr edit 3 --body \"cost is $(echo 5)\""))

# pflag joins a shorthand to its value, so this is a spelling gh honours and an
# exact-word match on "-b" would walk straight past.
check("-b joined to its value",
      "deny", run("gh pr comment 1 -b\"`id`\""))

check("--body= with an unquoted substitution",
      "deny", run("gh pr comment 1 --body=$(cat notes.md)"))

# The compound forms are the reason this hook takes the bare Bash matcher
# instead of an `if` anchored on a command prefix. A session that has just been
# refused reaches for exactly these.
check("gh after &&",
      "deny", run("cd /tmp && gh pr comment 1 --body \"`id`\""))

check("gh after ;",
      "deny", run("echo start; gh pr comment 1 --body \"`id`\""))

check("gh by absolute path",
      "deny", run("/opt/homebrew/bin/gh pr comment 1 --body \"`id`\""))

# --- allowed: inert, or the remedy itself -----------------------------------

check("single-quoted backtick is literal",
      "allow", run("gh pr comment 1 --body " + chr(39) + "see `date` here" + chr(39)))

check("single-quoted $( is literal",
      "allow", run("gh pr comment 1 --body " + chr(39) + "cost $(x)" + chr(39)))

# --body-file is the fix the denial recommends. A guard that fired on it would
# refuse the only spelling it offers.
check("--body-file untouched",
      "allow", run("gh pr comment 1 --body-file /tmp/body.md"))

check("--body-file with a body-ish path",
      "allow", run("gh pr create --title x --body-file \"$TMPDIR/body.md\""))

check("plain double-quoted prose",
      "allow", run("gh pr comment 1 --body \"nothing dangerous in here\""))

check("backslash-escaped backtick in double quotes",
      "allow", run("gh pr comment 1 --body \"a literal \\` tick\""))

check("no gh in the command",
      "allow", run("echo \"`date`\" > /tmp/x"))

check("gh with no body flag",
      "allow", run("gh pr view 47 --json title"))

check("${} parameter expansion is out of scope",
      "allow", run("gh pr comment 1 --body \"hello ${USER}\""))

# --- the hook never breaks the session --------------------------------------

check("malformed payload exits 0 and stays silent",
      "allow", run(None, raw="{not json"))

check("empty payload exits 0 and stays silent",
      "allow", run(None, raw=""))

check("payload with no command field",
      "allow", run(None, raw=json.dumps({
          "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {}})))

# --- the wiring, which the cases above cannot reach -------------------------
#
# Every case above feeds the script directly, so all of them pass on a hook that
# the harness never runs. What makes this guard work is the registration, and
# the one property worth pinning is the ABSENCE of an `if`: the dev_docs handler
# carries one to avoid spawning per write, and copying that here would narrow
# this guard to command prefixes and silently drop every compound form tested
# above.
root = os.environ["ROOT"]
with open(os.path.join(root, "hooks", "hooks.json")) as f:
    cfg = json.load(f)

entries = (cfg.get("hooks") or {}).get("PreToolUse") or []
mine = [(e, h) for e in entries for h in (e.get("hooks") or [])
        if "gh-body-guard.sh" in h.get("command", "")]

check("hooks.json runs the guard on PreToolUse", True, bool(mine))
check("its matcher covers Bash", True,
      all("Bash" in e.get("matcher", "") for e, _ in mine))
check("no handler carries an if that would narrow it", True,
      all(h.get("if") is None for _, h in mine))
check("the guard script is executable", True, os.access(guard, os.X_OK))

print("%d failures" % fails)
sys.exit(1 if fails else 0)
'
