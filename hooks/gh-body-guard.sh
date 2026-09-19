#!/usr/bin/env bash
# PreToolUse hook on Bash: denies a `gh` command that hands an unquoted or
# double-quoted `--body` argument to the shell with a command substitution in
# it.
#
# The failure this exists for is silent. `gh pr comment 1 --body "see `date`"`
# runs `date`, posts its output in place of the code span, and exits 0. Nothing
# reports it, because from gh's side nothing went wrong. The body can be edited
# afterwards only by someone who notices, and the rule in portable.md has been
# the only thing standing between a session and that outcome.
#
# It is not purely cosmetic. dotfiles' sandbox-network-guard.sh anchors its
# match on (^|[;&|]), so a network command inside a backtick is invisible to it
# too: the substitution runs before the guard ever sees a command word.
#
# Why this denies where hooks/dev-docs-context.sh advises. That hook carries
# guidance, so blocking would have denied the write that FIXES a violation.
# Neither half holds here. A command substitution in a body is not a style
# preference, and the corrective command is a different one --- `--body-file`
# --- so denying this call cannot block its own remedy.
#
# There is deliberately no escape hatch, which is the other difference from
# dotfiles' guard_pr_body.py. That guard polices style and offers a marker to
# override it. A marker here would be a way to ask for the exact behaviour the
# guard exists to prevent, and the safe spelling is always available: write the
# body to a file and pass --body-file.
#
# Why the bare `Bash` matcher rather than an `if` rule. The dev_docs handler
# uses `if` to avoid spawning on every write, and that is right for guidance
# whose trigger is a path the harness can test. This trigger is not: `gh` can
# appear after `&&`, inside a subshell, or behind `cd x;`, and an `if` anchored
# on a command prefix would miss exactly the compound forms a session reaches
# for when a simple one was refused. A guard that is correct on the easy case
# and blind on the hard one is worse than no guard, because it earns trust it
# has not got. The cost is paid down in the shell below rather than by
# narrowing the matcher: the two `case` tests exit before python is spawned, so
# a Bash call with no `gh` and no `--body` in it costs one short-lived shell.
#
# Detection is a raw-text scan, not a tokenizer. `shlex` in posix mode discards
# the quoting, which is the only thing separating the dangerous form from the
# safe one --- after tokenizing, `--body "see `date`"` and `--body 'see `date`'`
# are the same two strings. So the scanner below walks the command character by
# character and keeps each character's quote state alongside it.
#
# Exit 0 on every path that is not a deny, including a payload it cannot parse.
# A PreToolUse hook that exits nonzero blocks the tool call, and failing a
# session's command because this script could not read its own input would be a
# worse outcome than not checking it.
set -uo pipefail

payload="$(cat)"

# Cheap pre-filter. Both words must appear somewhere in the payload before it is
# worth starting python. `--body` alone is not enough (a `--body-file` call is
# the correct spelling and contains it), and `gh` alone matches most sessions.
case "$payload" in
  *'--body'* | *'-b'*) ;;
  *) exit 0 ;;
esac
case "$payload" in
  *gh*) ;;
  *) exit 0 ;;
esac

PAYLOAD="$payload" python3 -c '
import json, os, sys

try:
    hook = json.loads(os.environ["PAYLOAD"])
except (ValueError, KeyError):
    sys.exit(0)

command = (hook.get("tool_input") or {}).get("command") or ""
if not command:
    sys.exit(0)

OUT, SQ, DQ, ESC = "OUT", "SQ", "DQ", "ESC"


def scan(text):
    """Split into tokens, keeping every character next to its quote state.

    A token is a list of (char, state) pairs. ESC marks a character that a
    backslash made literal, so a `\\`` inside double quotes cannot be read as
    the start of a substitution.
    """
    tokens, cur, state, i = [], [], OUT, 0
    while i < len(text):
        c = text[i]
        if state == OUT:
            if c == "\x27":
                state, i = SQ, i + 1
                cur = cur or []
                continue
            if c == chr(34):
                state, i = DQ, i + 1
                cur = cur or []
                continue
            if c == chr(92):
                if i + 1 < len(text):
                    cur.append((text[i + 1], ESC))
                    i += 2
                    continue
                i += 1
                continue
            if c.isspace():
                if cur:
                    tokens.append(cur)
                    cur = []
                i += 1
                continue
            cur.append((c, OUT))
            i += 1
        elif state == SQ:
            if c == "\x27":
                state, i = OUT, i + 1
                continue
            cur.append((c, SQ))
            i += 1
        else:
            if c == chr(34):
                state, i = OUT, i + 1
                continue
            if c == chr(92) and i + 1 < len(text) and text[i + 1] in (chr(34), chr(92), "$", "`", "\n"):
                cur.append((text[i + 1], ESC))
                i += 2
                continue
            cur.append((c, DQ))
            i += 1
    if cur:
        tokens.append(cur)
    return tokens


def text_of(token):
    return "".join(ch for ch, _ in token)


def substitution_in(token):
    """The first command substitution the shell would actually run, or None.

    Single-quoted and backslash-escaped characters are inert, so only OUT and
    DQ states count. Parameter expansion (${...}) is left alone: the rule in
    portable.md names backticks and $(, and widening a deny guard past its
    written rule is how false positives start.
    """
    for j, (ch, st) in enumerate(token):
        if st in (SQ, ESC):
            continue
        if ch == "`":
            return "`"
        if ch == "$" and j + 1 < len(token):
            nxt, nxt_state = token[j + 1]
            if nxt == "(" and nxt_state != SQ:
                return "$("
    return None


tokens = scan(command)
words = [text_of(t) for t in tokens]

# Require a gh invocation. Without it a --body flag belongs to some other tool
# and this guard has no rule to enforce.
if not any(w == "gh" or w.endswith("/gh") for w in words):
    sys.exit(0)

found = None
for idx, word in enumerate(words):
    value = None
    # --body-file is the remedy, not the hazard, and it starts with --body.
    # Match the flag exactly, or as --body=<value>.
    if word in ("--body", "-b"):
        if idx + 1 < len(tokens):
            value = tokens[idx + 1]
    elif word.startswith("--body="):
        value = tokens[idx][len("--body="):]
    elif len(word) > 2 and word[0] == "-" and word[1] == "b":
        # pflag accepts a shorthand joined to its value, so `-b$(date)` is a
        # real spelling gh honours. `--body` cannot reach here: its second
        # character is a dash.
        value = tokens[idx][2:]
    if value is None:
        continue
    hit = substitution_in(value)
    if hit:
        found = (word, hit)
        break

if not found:
    sys.exit(0)

flag, hit = found
reason = (
    "Refusing this command: the " + flag + " argument contains " + hit
    + ", which the shell runs before gh ever sees it. gh would post the "
    "output of that substitution in place of the code span, exit 0, and "
    "report nothing. portable.md: \"Never pass prose containing backticks "
    "to --body.\"\n\n"
    "Write the body to a file and pass it instead:\n"
    "  printf %s \"$body\" > \"$TMPDIR/body.md\"\n"
    "  gh ... --body-file \"$TMPDIR/body.md\"\n\n"
    "Single-quoting the argument also stops the substitution, but a body is "
    "prose and will eventually contain an apostrophe, so --body-file is the "
    "spelling that keeps working."
)

json.dump({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}, sys.stdout)
' 2>/dev/null

exit 0
