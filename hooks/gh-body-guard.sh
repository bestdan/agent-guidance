#!/usr/bin/env bash
# PreToolUse hook on Bash: denies a `gh` command that hands an unquoted or
# double-quoted free-text argument to the shell with a command substitution in
# it. The guarded flags are `--body`, `--title` and `--notes`.
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
# guard exists to prevent, and a safe spelling is always available: a file for
# the flags that read one, single quotes for the flags that do not.
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

# Cheap pre-filter, and the selective half is the first test rather than the
# flag names. substitution_in() below can only ever report a backtick or a `$(`,
# so a payload containing neither cannot produce a deny whatever flags it
# carries. Testing the flags instead would short-circuit almost nothing now that
# `-t` and `-n` are in scope --- both match ordinary paths and ordinary flags of
# other commands.
case "$payload" in
  *'`'* | *'$('*) ;;
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

# The free-text flags, each mapped to the file-based counterpart the denial
# should recommend. None means the flag has no counterpart, so the denial has to
# offer quoting instead --- see reason_for() at the bottom.
#
# Long flags need no disambiguation: gh spells --body, --title and --notes the
# same way under every command that accepts them, and no command gives those
# names to anything that is not prose.
LONG = {
    "--body": "--body-file",
    "--title": None,
    "--notes": "--notes-file",
    "--description": None,
    "--desc": None,
    "--readme": None,
    "--subject": None,
}

# The last four take no shorthand entry, deliberately. -d is --description on
# gh repo create and gh repo edit and --desc on gh gist create, but it is
# --draft on gh pr create and gh release create and --delete-branch on
# gh pr merge, so the letter says nothing on its own. -t is --subject on
# gh pr merge, which is why that command is absent from the -t path list above:
# a shorthand there would deny under the wrong flag name. The long forms carry
# the whole coverage for these four; the class in portable.md is what a session
# reads, and a shorthand adds a table for no case anyone writes.

# Shorthands do need it. gh reuses single letters across subcommands, so a
# shorthand names a prose flag only under the commands that spell it that way.
# Each entry is the long flag plus the command paths that do, as a prefix of the
# non-flag words following gh.
#
# Surveyed against gh 2.98.0 on 2026-09-20; re-survey before widening. The
# collisions that make this table necessary rather than cosmetic:
#   -b is --base on `gh issue develop`
#   -t is --template (a Go output template) on `gh api`, `gh project create`,
#      `gh project edit`, and every list command that prints JSON
#   -n is --name on `gh issue develop`
#
# Listing the commands that DO spell it this way, rather than the ones that do
# not, is deliberate. A table that goes stale then fails toward allowing a new
# spelling, which is a missed deny; the inverse fails toward refusing a command
# nobody could predict a refusal for, and an unpredictable deny with no hatch is
# how this guard would lose the trust that makes it worth having.
SHORT = {
    "-b": ("--body", (
        ("pr", "create"), ("pr", "edit"), ("pr", "comment"), ("pr", "review"),
        ("pr", "merge"), ("issue", "create"), ("issue", "edit"),
        ("issue", "comment"),
    )),
    "-t": ("--title", (
        ("pr", "create"), ("pr", "edit"), ("issue", "create"),
        ("issue", "edit"), ("release", "create"), ("release", "edit"),
    )),
    "-n": ("--notes", (
        ("release", "create"), ("release", "edit"),
    )),
}


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


# The gh top-level commands SHORT names. The path is anchored on one of these
# rather than read off the leading non-flag words, because a flag that takes a
# value puts a non-flag word in front of the subcommand: gh accepts
# `gh -R owner/repo pr comment 1 -b ...`, and reading the first two non-flag
# words there gives (owner/repo, pr), which matches nothing and lets the
# shorthand through. Anchoring cannot be fooled that way, since a repo argument
# is owner/name and never equals a bare command word.
ROOTS = ("pr", "issue", "release")


def command_path(words):
    """The gh subcommand path: a ROOTS word and the next non-flag word after it.

    Only used to disambiguate a shorthand. A command whose root is not in ROOTS
    yields the empty path, which matches no SHORT entry, so the shorthand is not
    treated as a prose flag --- the same direction the stale-table note above
    chooses.
    """
    for i, word in enumerate(words):
        if word in ROOTS:
            for later in words[i + 1:]:
                if not later.startswith("-"):
                    return (word, later)
            return (word,)
    return ()


def spells(paths, path):
    return any(path[:len(p)] == p for p in paths)


def flag_and_value(word, token, nxt, path):
    """Resolve one word to (long flag, value token), or (None, None).

    Four spellings reach a value: the long flag and its value as separate
    words, --flag=value, the shorthand and its value as separate words, and the
    shorthand joined to its value. pflag accepts the last one, so -t`date` is a
    real spelling gh honours and an exact-word match walks straight past it.
    """
    if word in LONG:
        return word, nxt
    if word in SHORT and spells(SHORT[word][1], path):
        return SHORT[word][0], nxt
    for long in LONG:
        # --body-file is the remedy, not the hazard, and it starts with --body.
        # Match the flag exactly, or as --flag=<value>.
        if word.startswith(long + "="):
            return long, token[len(long) + 1:]
    if len(word) > 2 and word[0] == "-" and word[1] != "-":
        short = "-" + word[1]
        # A long flag cannot reach here: its second character is a dash.
        if short in SHORT and spells(SHORT[short][1], path):
            return SHORT[short][0], token[2:]
    return None, None


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

    path = command_path(words[gh_at + 1:])

    for idx in range(gh_at + 1, len(words)):
        nxt = tokens[idx + 1] if idx + 1 < len(tokens) else None
        flag, value = flag_and_value(words[idx], tokens[idx], nxt, path)
        if value is None:
            continue
        hit = substitution_in(value)
        if hit:
            found = (words[idx], flag, hit)
            break
    if found:
        break

if not found:
    sys.exit(0)

typed, flag, hit = found
remedy = LONG[flag]

reason = (
    "Refusing this command: the " + typed + " argument contains " + hit
    + ", which the shell runs before gh ever sees it. gh would post the "
    "output of that substitution in place of the " + hit
    + " expression, exit 0, and "
    "report nothing. portable.md: \"Never pass prose containing backticks "
    "to a free-text gh flag.\"\n\n"
)

if remedy:
    reason += (
        "Write the text to a file and pass it instead:\n"
        "  printf %s \"$text\" > \"$TMPDIR/text.md\"\n"
        "  gh ... " + remedy + " \"$TMPDIR/text.md\"\n\n"
        "Single-quoting the argument also stops the substitution, but prose "
        "this long will eventually contain an apostrophe, so " + remedy
        + " is the spelling that keeps working."
    )
else:
    reason += (
        flag + " reads no file, so single-quote the argument instead:\n"
        "  gh ... " + flag + " \x27fix(scope): handle a bare tilde\x27\n\n"
        "Quoting is the answer here rather than a file because this flag has no "
        "file-reading counterpart, and a one-line value rarely carries an "
        "apostrophe. If this one does, drop the " + hit + " expression."
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
