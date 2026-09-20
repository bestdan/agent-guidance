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
# narrowing the matcher: the two `case` tests exit before python is spawned.
# Both tests are plain substring globs, so they short-circuit fewer calls than
# that reads --- `gh` matches "through" and "highlight", and `-b` matches any
# path carrying it. Nothing here has been timed.
#
# Detection is a raw-text scan, not a tokenizer. `shlex` in posix mode discards
# the quoting, which is the only thing separating the dangerous form from the
# safe one --- after tokenizing, `--body "see `date`"` and `--body 'see `date`'`
# are the same two strings. So the scanner below walks the command character by
# character and keeps each character's quote state alongside it.
#
# It also splits the command into segments, because a `--body` belongs to the
# command it sits in. Without that, `curl -b "$(cat jar)" && gh pr view 1` is
# refused for a flag gh never receives --- and a deny here has no way past it.
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
    """Split into segments of tokens, each character kept with its quote state.

    A token is a list of (char, state) pairs. ESC marks a character a backslash
    made literal, so a backslash-escaped backtick inside double quotes is not
    read as opening a substitution.

    A segment is a run of tokens the shell hands to one command. The split is
    what stops a --body in one command being attributed to a gh in another.

    An unquoted $( or backtick ends a segment but keeps its own characters in
    the token being built. That order is load-bearing in both directions: the
    characters must stay so the value of --body $(cat x) still reads as a
    substitution, and the break must happen so the gh inside echo $(gh ...)
    starts a command of its own.
    """
    segments, tokens, cur, state, i = [], [], [], OUT, 0
    # `started` is what makes an empty quoted word a word. bash passes "" as a
    # real, empty argument, so a scanner that emits no token for it shifts every
    # later argument left by one and reads the wrong one as the body value.
    started = False

    def flush():
        nonlocal cur, started
        if cur or started:
            tokens.append(cur)
            cur = []
            started = False

    def cut():
        nonlocal tokens
        flush()
        if tokens:
            segments.append(tokens)
            tokens = []

    while i < len(text):
        c = text[i]
        if state == OUT:
            if c == chr(92) and i + 1 < len(text) and text[i + 1] == chr(10):
                # A line continuation: bash removes both characters. Treating
                # the newline as an escaped literal instead would leave
                # --bo\<newline>dy as a word that matches no flag, so the body
                # it introduces would go unchecked.
                i += 2
                continue
            if c == chr(92):
                if i + 1 < len(text):
                    cur.append((text[i + 1], ESC))
                    i += 2
                    continue
                i += 1
                continue
            if c == "\x27":
                state, i = SQ, i + 1
                started = True
                continue
            if c == chr(34):
                state, i = DQ, i + 1
                started = True
                continue
            if c == "$" and i + 1 < len(text) and text[i + 1] == "(":
                cur.append((c, OUT))
                cur.append(("(", OUT))
                i += 2
                cut()
                continue
            if c == "`":
                cur.append((c, OUT))
                i += 1
                cut()
                continue
            if c == "#" and not cur and not started:
                # bash starts a comment at a word boundary, so nothing after it
                # on this line runs. Without this a trailing comment reads as a
                # live body argument.
                nl = text.find(chr(10), i)
                if nl == -1:
                    break
                i = nl + 1
                cut()
                continue
            if c in ";&|()" + chr(10):
                i += 1
                cut()
                continue
            if c.isspace():
                flush()
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
            if c == chr(92) and i + 1 < len(text) and text[i + 1] == chr(10):
                i += 2
                continue
            if c == chr(92) and i + 1 < len(text) and text[i + 1] in (chr(34), chr(92), "$", "`"):
                cur.append((text[i + 1], ESC))
                i += 2
                continue
            cur.append((c, DQ))
            i += 1
    cut()
    return segments


def text_of(token):
    return "".join(ch for ch, _ in token)


def substitution_in(token):
    """The first command substitution the shell would actually run, or None.

    Single-quoted and backslash-escaped characters are inert, so only OUT and
    DQ states count. Parameter expansion (${...}) is left alone: the rule in
    portable.md names backticks and $(, and widening a deny guard past its
    written rule is how false positives start. Arithmetic expansion, $((, is
    left alone for the opposite reason --- it runs no command, but a body
    carrying it is shell code either way, and the branch that told the two
    apart would have to decide an ambiguity bash itself resolves by trying.
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


found = None
for tokens in scan(command):
    words = [text_of(t) for t in tokens]

    # A gh anywhere in the segment, not only at its head, so that a leading
    # env assignment or a wrapper still resolves to the same command.
    gh_at = None
    for k, word in enumerate(words):
        if word == "gh" or word.endswith("/gh"):
            gh_at = k
            break
    if gh_at is None:
        continue

    for idx in range(gh_at + 1, len(words)):
        word = words[idx]
        value = None
        # --body-file is the remedy, not the hazard, and it starts with --body.
        # Match the flag exactly, or as --body=<value>.
        if word in ("--body", "-b"):
            if idx + 1 < len(tokens):
                value = tokens[idx + 1]
        elif word.startswith("--body="):
            value = tokens[idx][len("--body="):]
        elif len(word) > 2 and word[0] == "-" and word[1] == "b":
            # pflag accepts a shorthand joined to its value, so -b$(date) is a
            # real spelling gh honours. --body cannot reach here: its second
            # character is a dash.
            value = tokens[idx][2:]
        if value is None:
            continue
        hit = substitution_in(value)
        if hit:
            found = (word, hit)
            break
    if found:
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
