#!/usr/bin/env bash
# PreToolUse hook on Write and Edit: when a session is about to add a code
# comment carrying a tracker key outside a `TODO`, say so before the tool call
# runs. `portable.md`: "A comment carries no ticket key and no PR number: a
# reader with no tracker access has the whole explanation, or the comment has
# failed."
#
# Advises, never denies. `dev_docs/decisions/2026-09-16-dev-docs-hook-never-denies-the-write.md`
# is the reasoning and it applies unchanged: the write that REMOVES a key must
# not be blocked alongside the write that adds one, and the remedy -- delete the
# key, keep the sentence -- is cheap enough that a pointer buys the whole fix.
# Exit 0 on every path, including a payload this script cannot parse.
#
# The hard part is "added lines only". A key in a comment that pre-dates the
# rule is not a finding, and a guard that fires on untouched text is the false
# positive that makes a check worse than the prose it enforces. The two tools
# give the added text differently, so the script computes it rather than
# trusting either payload:
#
#   Edit  -- old text is `old_string`, new text is `new_string`. `new_string`
#            is not purely added: an edit that reindents a block, or one that
#            appends a line to a function it quotes for context, carries the
#            untouched lines through both sides.
#   Write -- new text is `content`, old text is the file on disk. A new file
#            reads as an empty old text, so every line is added, which is
#            correct. An existing file would otherwise report every key it
#            already carries on the first unrelated write to it.
#
# A line is added when it does not appear, stripped, anywhere in the old text.
# That is a line-set difference rather than a diff: a key-bearing comment
# that MOVES is not reported, which is a missed finding in the safe direction.
# `dev_docs/decisions/2026-09-20-added-lines-are-the-new-text-minus-the-old.md`
# has the reasoning and the cases it gives up.
#
# Why the bare `Write|Edit` matcher and no `if` rule. `if` narrows on a path
# glob, and this trigger is every source file in the repo -- there is no path to
# narrow to, and a negative glob (everything but `*.md`) is not a thing `if`
# expresses. So this takes the `hooks/gh-body-guard.sh` shape instead: the bare
# matcher, with the cost paid down in the shell below, where a `case` test on
# the raw payload exits before python3 starts.
#
# Why no once-per-session marker. The `dev_docs/` pointer is the same paragraph
# every time, so a session needs it once. This names a specific line in a
# specific file, and the second offending comment is a different finding from
# the first.
#
# The program is comment-key-context.py beside this file, not a `python3 -c`
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

# Cheap pre-filter. A payload with no `<uppercase><uppercase>...-<digit>`
# anywhere in it cannot produce a finding, whatever else it contains. The test
# is looser than the key regex in comment-key-context.py -- it has to be, as a
# shell glob -- so it over-admits and never over-rejects.
case "$payload" in
  *[A-Z][A-Z]*-[0-9]*) ;;
  *) exit 0 ;;
esac

PAYLOAD="$payload" python3 "$here/comment-key-context.py" 2>/dev/null

exit 0
