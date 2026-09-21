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
set -uo pipefail

payload="$(cat)"

# Cheap pre-filter. A payload with no `<uppercase><uppercase>...-<digit>`
# anywhere in it cannot produce a finding, whatever else it contains. The test
# is looser than the key regex in python below -- it has to be, as a shell glob
# -- so it over-admits and never over-rejects.
case "$payload" in
  *[A-Z][A-Z]*-[0-9]*) ;;
  *) exit 0 ;;
esac

PAYLOAD="$payload" python3 -c '
import json, os, re, sys

try:
    hook = json.loads(os.environ["PAYLOAD"])
except (ValueError, KeyError):
    sys.exit(0)

tool = hook.get("tool_name") or ""
ti = hook.get("tool_input") or {}
path = ti.get("file_path") or ""
if not path:
    sys.exit(0)

# Prose formats are excluded by extension. A decision record, a README or a
# changelog cites a tracker key as a matter of course, and markdown hands a
# bare `#` to every heading, so a marker scan there would report a heading as a
# comment. The list fails toward firing on a format nobody named, which is the
# direction an advisory hook can afford.
PROSE = {".md", ".markdown", ".mdx", ".txt", ".rst", ".adoc", ".org"}
if os.path.splitext(path)[1].lower() in PROSE:
    sys.exit(0)

if tool == "Edit":
    old, new = ti.get("old_string") or "", ti.get("new_string") or ""
elif tool == "Write":
    new = ti.get("content") or ""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            old = fh.read()
    except OSError:
        # No file on disk is a new file, where every line is added. An
        # unreadable one takes the same branch and reports more than it should;
        # the cost is a pointer, and the alternative is staying silent on the
        # case the guard exists for.
        old = ""
else:
    sys.exit(0)

if not new:
    sys.exit(0)

existing = set(line.strip() for line in old.splitlines())

# Two letters minimum, and letters only. Real keys are PRE-999, ENG-9,
# ABC-142; a one-letter prefix is `X-11` and a prefix carrying a digit is
# `Q1-2026` far more often than either is a tracker. Jira permits a digit in a
# project key after the first character, so this gives up a key spelled that
# way, which is the direction that costs a missed pointer rather than a false
# one on every quarter named in a comment.
KEY = re.compile(r"(?<![A-Za-z0-9_-])([A-Z]{2,10})-(\d{1,6})(?![0-9])")

# Prefixes that spell a standard, an algorithm or a unit rather than a tracker.
# Snapshot, not a closed set: a prefix nobody listed produces a pointer that a
# reader dismisses, and a tracker key sharing a name with a standard goes
# unreported. Both are cheap; neither blocks a write.
NOT_TRACKERS = {
    "AES", "ANSI", "ASCII", "BCP", "CP", "CVE", "CWE", "DSA", "EC", "ECMA",
    "EUC", "GB", "GMT", "GPT", "HTTP", "IEC", "IPV", "ISO", "KOI", "LATIN",
    "MAC", "MD", "PCI", "PEP", "RFC", "RGB", "RSA", "SHA", "SSL", "STD", "TLS",
    "UCS", "USB", "UTC", "UTF", "WCAG", "WIN",
}


def comment_at(line):
    """The index where a comment starts on this line, or None.

    A marker scan rather than a parser. The alternative is a per-language
    tokenizer, and this hook runs in every repo a session touches, so the
    language is whatever the extension says and often nothing this script has
    heard of. Three known cases it gives up, two of them toward silence:

      - A block comment whose body carries no leading `*`. The key line
        between `/*` and `*/` holds no marker of its own, so it is missed.
        Tracking the state across lines is not available: `new` is a
        fragment, and a tracker that guessed at its opening state would
        report keys on ordinary code.
      - A comment marker with nothing before it, such as `x=1;#note`. The
        `#` scan below requires whitespace or line start, which is what buys
        the URL-fragment case.
      - A marker inside a string literal, which fails the other way and
        reports: `s = "tag #ABC-123"` reads as a comment, because the `#` has
        whitespace before it like any other. Telling the two apart needs the
        parser this function does without.
    """
    best = None

    def note(i):
        return i if best is None else min(best, i)

    # `//` preceded by a colon is a URL scheme, not a comment. That single
    # exception carries most of the false positives this scan would otherwise
    # produce: a bare string "https://example.com/UTF-8" is not a comment.
    start = 0
    while True:
        i = line.find("//", start)
        if i == -1:
            break
        if i == 0 or line[i - 1] != ":":
            best = note(i)
            break
        start = i + 2

    # A `#` with a non-space before it is a URL fragment, a CSS colour or an
    # HTML anchor rather than a comment. The walk continues past one rather
    # than stopping, so the `# note` after a `"#FFF"` literal is still found.
    start = 0
    while True:
        i = line.find("#", start)
        if i == -1:
            break
        if i == 0 or line[i - 1].isspace():
            best = note(i)
            break
        start = i + 1

    for marker in ("/*", "<!--"):
        i = line.find(marker)
        if i != -1:
            best = note(i)

    stripped = line.lstrip()
    indent = len(line) - len(stripped)
    # A javadoc continuation line, and the SQL/Lua/Haskell `--`. `--` is taken
    # only with a space after it, so a `--flag` in a shell line is not a
    # comment marker.
    if stripped.startswith("* ") or stripped == "*":
        best = note(indent)
    if stripped.startswith("-- "):
        best = note(indent)
    j = line.find(" -- ")
    if j != -1:
        best = note(j + 1)

    return best


findings = []
for n, line in enumerate(new.splitlines(), 1):
    if line.strip() in existing:
        continue
    at = comment_at(line)
    if at is None:
        continue
    # `TODO` is the exception the rule names, and it counts only inside the
    # comment: a `"TODO"` string in the code says nothing about the comment
    # beside it. The test is the word rather than `TODO(KEY):`, because
    # `# TODO: fix per PRE-999` is the same exception spelled differently and
    # the reason the rule gives for it -- the key names outstanding work
    # rather than citing a source -- holds there too.
    #
    # No apostrophe in this block, or anywhere else inside it: the whole
    # program is a single-quoted shell argument, and one apostrophe ends it.
    if "TODO" in line[at:]:
        continue
    for match in KEY.finditer(line[at:]):
        if match.group(1) in NOT_TRACKERS:
            continue
        findings.append((n, match.group(0), line.strip()))
        break

if not findings:
    sys.exit(0)

lines = [
    "This " + ("edit" if tool == "Edit" else "write") + " adds a code comment "
    "carrying a tracker key. portable.md: \"A comment carries no ticket key "
    "and no PR number: a reader with no tracker access has the whole "
    "explanation, or the comment has failed.\" A `TODO(KEY):` is the "
    "exception, because there the key names outstanding work rather than "
    "citing a source.",
    "",
]
for n, key, text in findings[:5]:
    lines.append("  line " + str(n) + ": " + key + " in " + text[:120])
if len(findings) > 5:
    lines.append("  ... and " + str(len(findings) - 5) + " more")
lines += [
    "",
    "Delete the key and keep the sentence. If the key was carrying the "
    "explanation, write the explanation into the comment instead: the reader "
    "of this line may have no access to that tracker, and the item outlives "
    "nothing.",
]

json.dump({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": "\n".join(lines),
    }
}, sys.stdout)
' 2>/dev/null

exit 0
