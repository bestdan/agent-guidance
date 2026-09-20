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


def reason(command):
    """The denial reason text, or "" when the command was allowed."""
    payload = json.dumps({
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "session_id": "test",
        "tool_input": {"command": command},
    })
    proc = subprocess.run(
        ["bash", guard], input=payload, capture_output=True, text=True
    )
    out = proc.stdout.strip()
    if not out:
        return ""
    try:
        body = json.loads(out)
    except ValueError:
        return ""
    return ((body.get("hookSpecificOutput") or {}).get("permissionDecisionReason")) or ""


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

# A line continuation inside the flag word is the one spelling that bypassed the
# guard: bash removes the backslash-newline and gh receives --body, while a
# scanner treating the newline as an escaped literal matches no flag at all.
check("line continuation inside the flag word",
      "deny", run("gh pr comment 1 --bo" + chr(92) + chr(10) + "dy " + chr(34) + "`date`" + chr(34)))

check("ordinary multi-line continuation",
      "deny", run("gh pr comment 1 " + chr(92) + chr(10) + "  --body " + chr(34) + "`date`" + chr(34)))

# gh inside a substitution is a command of its own. The segment break after an
# unquoted $( is what lets the scanner see it.
check("gh nested in a substitution",
      "deny", run("echo $(gh pr comment 1 --body " + chr(34) + "`date`" + chr(34) + ")"))

# --- denied: the other free-text flags --------------------------------------
#
# --title is the one that will actually bite. A PR title routinely carries a
# code span, and it is the field the Git: bullet in portable.md gives a grammar
# for. Each flag repeats the four spellings --body is pinned on, because the
# resolution path differs per spelling and a shorthand differs again per
# command.

check("--title double-quoted backtick",
      "deny", run("gh pr create --title \"fix `date` handling\" --body-file b.md"))

check("--title= joined form",
      "deny", run("gh issue create --title=\"a `id` b\" --body-file b.md"))

check("--title with an unquoted substitution",
      "deny", run("gh pr edit 3 --title $(cat subject)"))

check("-t shorthand under a command that spells it --title",
      "deny", run("gh release edit v1 -t \"`date`\""))

check("-t joined to its value",
      "deny", run("gh issue edit 5 -t\"`id`\""))

# --title is a long flag, so it needs no command to vouch for it: no gh command
# gives that name to anything but prose.
check("--title under a command the -t table does not list",
      "deny", run("gh project create --owner @me --title \"`id`\""))

# The remaining prose flags. All three read no file, so they take the quoting
# remedy, and all three are long-form only --- -d is --draft on the commands
# that have one.
check("--description double-quoted backtick",
      "deny", run("gh repo edit --description \"a `date` b\""))

check("--desc= joined form on gist create",
      "deny", run("gh gist create f.txt --desc=\"a `id` b\""))

check("--readme with an unquoted substitution",
      "deny", run("gh project edit 1 --readme $(cat readme.md)"))

# --desc is a prefix of --description, so an exact-or-`=` match is what keeps
# the longer flag from being read as the shorter one with a stray value.
check("--description= is not read as --desc",
      "deny", run("gh repo create x --description=\"a `id` b\""))

check("--subject on gh pr merge",
      "deny", run("gh pr merge 1 --squash --subject \"fix: `date` handling\""))

# -t is --subject on gh pr merge, not --title, so the shorthand is left alone
# there rather than denied under a flag name gh never received.
check("-t on gh pr merge is left to the long form",
      "allow", run("gh pr merge 1 --squash -t \"$(cat subject)\""))

check("-d stays --draft, not --description",
      "allow", run("gh release create v1 -d \"$(cat notes)\" --notes-file n.md"))

check("--notes double-quoted backtick",
      "deny", run("gh release create v1 --notes \"built `date`\""))

check("--notes= joined form",
      "deny", run("gh release edit v1 --notes=\"a `id` b\""))

check("-n shorthand under a command that spells it --notes",
      "deny", run("gh release create v1 -n \"`date`\""))

check("-n joined to its value",
      "deny", run("gh release create v1 -n\"`date`\""))

# --- allowed: a shorthand that means something else under this command ------
#
# gh reuses single letters across subcommands, which is why the shorthand table
# is keyed on the command path. Surveyed against gh 2.98.0 on 2026-09-20. Each
# of these would be a hard stop with no way past it if the shorthand were
# matched on its own.

# A value-taking flag before the subcommand puts a non-flag word in front of it.
# Reading the leading non-flag words gave (o/r, pr) here, which matches nothing,
# so the shorthand went unguarded --- and for -b that was a deny main already
# made. The path is anchored on the command word instead.
check("-R before the subcommand does not hide --body",
      "deny", run("gh -R o/r pr comment 1 -b \"`date`\""))

check("-R before the subcommand does not hide --title",
      "deny", run("gh -R o/r pr create -t \"`date`\" --body-file b.md"))

check("--repo before the subcommand does not hide --notes",
      "deny", run("gh --repo o/r release create v1 -n \"`date`\""))

check("-t is a Go output template on gh api",
      "allow", run("gh api repos/a/b -t \"$(cat fmt.tmpl)\""))

check("-t is a Go output template on gh project create",
      "allow", run("gh project create --owner @me -t \"$(cat fmt.tmpl)\""))

check("-t is a Go output template on gh project edit",
      "allow", run("gh project edit 1 --owner @me -t \"$(cat fmt.tmpl)\""))

check("-t is a Go output template on a list command",
      "allow", run("gh pr list -t \"$(cat fmt.tmpl)\""))

check("-b is --base on gh issue develop",
      "allow", run("gh issue develop 5 -b \"$(cat base)\""))

check("-n is --name on gh issue develop",
      "allow", run("gh issue develop 5 -n \"$(cat name)\""))

# --notes-file is the remedy for --notes, exactly as --body-file is for --body.
check("--notes-file untouched",
      "allow", run("gh release create v1 --notes-file /tmp/notes.md"))

check("--notes-start-tag is not --notes",
      "allow", run("gh release create v1 --notes-start-tag \"$(cat tag)\" --notes-file n.md"))

# A pflag cluster whose guarded flag is not first passes, deliberately. The
# decision record argues it: the table that would close it is one of boolean
# shorthands per command, and that table going stale refuses a correct command
# rather than missing a deny. Pinned as a case so a later widening has to change
# it on purpose.
check("a shorthand cluster passes, per the 2026-09-20 record",
      "allow", run("gh release create v1 -dt \"`date`\" --notes-file n.md"))

check("single-quoted title is literal",
      "allow", run("gh pr create --title " + chr(39) + "fix `date` handling" + chr(39) + " --body-file b.md"))

# --- allowed: inert, or the remedy itself -----------------------------------

# A body flag belongs to the command it sits in. These were denied by the
# whole-command scan, and they are ordinary shell rather than exotica.
check("-b belongs to the other command in the compound",
      "allow", run("sort -b " + chr(34) + "$(cat list)" + chr(34) + " && gh pr view 1"))

check("--body belongs to the other command in the compound",
      "allow", run("printf --body " + chr(34) + "$(id)" + chr(34) + " && gh pr view 1"))

check("body flag before gh, separated by a semicolon",
      "allow", run("echo --body " + chr(34) + "`date`" + chr(34) + "; gh pr view 1"))

check("trailing comment is not live text",
      "allow", run("gh pr view 1 # --body " + chr(34) + "`date`" + chr(34)))

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

# An empty quoted argument is a real argument to bash, so a scanner that drops it
# reads the NEXT argument as the body and refuses a correct command.
check("empty quoted body, danger in a later argument",
      "allow", run("gh pr comment 1 --body \"\" \"$(date)\""))

# The deny is only defensible because it names the spelling that works. Nothing
# pinned that: the harness above checks a reason exists, not what it says.
check("the denial names --body-file",
      True, "--body-file" in reason("gh pr comment 1 --body \"`date`\""))

# The remedy has to exist for the flag the guard fired on. --title reads no
# file, so a denial that recommended --body-file would be sending the session to
# a flag gh will reject --- and with no hatch, that is a dead end rather than a
# detour.
title_reason = reason("gh pr create --title \"`date`\" --body-file b.md")
check("the --title denial does not recommend --body-file",
      False, "--body-file" in title_reason)
check("the --title denial offers quoting instead",
      True, "single-quote" in title_reason)

check("the --notes denial names --notes-file",
      True, "--notes-file" in reason("gh release create v1 --notes \"`date`\""))

# The denial quotes the rule it enforces, so the quote has to be the widened
# rule rather than the one that named a single flag.
check("the denial quotes the rule as a class",
      True, "free-text gh flag" in reason("gh pr comment 1 --body \"`date`\""))

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
