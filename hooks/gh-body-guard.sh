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
#
# The program is gh-body-guard.py beside this file, not a `python3 -c`
# argument. That argument was parsed by nothing: shellcheck sees one opaque
# string, and a python checker sees no file to open. So a truncated program was
# a hook that said nothing on every payload, with nothing reporting it. A
# missing or unparsable `.py` file fails the same silent way, because the
# never-block rule above is unconditional; what changes is that the failure is
# findable before it ships.
# `dev_docs/decisions/2026-09-20-hook-python-lives-in-a-file-beside-the-shell.md`
# is the record.
#
# The `case` prefilter below stays in the shell. It exists so python never
# starts on most calls, and moving it into the program would undo the
# measurement behind it
# (`dev_docs/decisions/2026-09-19-the-body-guard-takes-the-bare-bash-matcher.md`).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

PAYLOAD="$payload" python3 "$here/gh-body-guard.py" 2>/dev/null

exit 0
