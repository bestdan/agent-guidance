#!/usr/bin/env python3
"""Reports prose-rule breaks in the text a write adds.

Run by hooks/prose-context.sh, which reads the PreToolUse payload into PAYLOAD
and the plugin root into GUIDANCE_ROOT.

Two checks share the added-lines computation and split on the file's extension:
a tracker key in a code comment for source files, and insider prose for
markdown. Why this is a file rather than a `python3 -c` argument, and what the
wrapper keeps: `dev_docs/decisions/2026-09-20-hook-python-lives-in-a-file-beside-the-shell.md`.
The wrapper carries the reasoning for the behaviour below; it is the file a
reader arrives at from hooks.json, and this is the program it runs.
"""

import json
import os
import pathlib
import re
import sys

try:
    hook = json.loads(os.environ["PAYLOAD"])
except (ValueError, KeyError):
    sys.exit(0)
if not isinstance(hook, dict):
    sys.exit(0)

tool = hook.get("tool_name") or ""
ti = hook.get("tool_input") or {}
path = ti.get("file_path") or ""
if not path:
    sys.exit(0)

# Prose formats are excluded from the comment-key check by extension. A
# decision record, a README or a changelog cites a tracker key as a matter of
# course, and markdown hands a bare `#` to every heading, so a marker scan there
# would report a heading as a comment. The list fails toward firing on a format
# nobody named, which is the direction an advisory hook can afford.
PROSE = {".md", ".markdown", ".mdx", ".txt", ".rst", ".adoc", ".org"}
# The subset the insider-prose check reads. The wrapper's prefilter admits
# these same three by path; a fourth added here and not there never runs.
MARKDOWN = {".md", ".markdown", ".mdx"}
ext = os.path.splitext(path)[1].lower()
if ext in PROSE and ext not in MARKDOWN:
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

existing = set(line.strip() for line in old.splitlines())


def added(line):
    return line.strip() not in existing


def emit(lines):
    json.dump({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": "\n".join(lines),
        }
    }, sys.stdout)
    sys.exit(0)


# --- markdown: insider prose -------------------------------------------------

HEADING = "## Don't write insider prose"
# One single-line HTML comment. The hook holds added lines, so a comment that
# opens on one line and closes on another has no pairing to strip, and is left.
HTML_COMMENT = re.compile(r"<!--.*?-->")


def first_markdown_write():
    """True once per session. Same marker shape as dev-docs-context.py."""
    scratch = hook.get("scratchpad_dir") or "/tmp/claude"
    session = hook.get("session_id") or "unknown"
    marker = pathlib.Path(scratch) / (".prose-context-" + str(session))
    try:
        marker.parent.mkdir(parents=True, exist_ok=True)
        if marker.exists():
            return False
        marker.touch()
    except OSError:
        # An unwritable marker directory means the pointer repeats rather than
        # never arriving. Repetition is the cheaper failure.
        pass
    return True


def read_section(root):
    """(text, None) for the rule's section, or (None, why) on any miss.

    Exactly one heading, or it is a miss. A second match means the file was
    restructured, and quoting whichever came first would hand the reader a
    section nobody chose.
    """
    if not root:
        return None, "GUIDANCE_ROOT is unset"
    source = os.path.join(root, "writing_about_code.md")
    try:
        with open(source, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as e:
        return None, "cannot read " + source + ": " + e.strerror
    starts = [m.start() for m in re.finditer("^" + re.escape(HEADING) + "$", text, re.M)]
    if len(starts) != 1:
        return None, "%s carries %d '%s' headings, not 1" % (source, len(starts), HEADING)
    rest = text[starts[0]:]
    end = re.search(r"^## ", rest[len(HEADING):], re.M)
    body = rest if end is None else rest[:len(HEADING) + end.start()]
    return body.strip(), None


def markdown():
    root = os.environ.get("GUIDANCE_ROOT") or ""
    out = []

    if first_markdown_write():
        section, miss = read_section(root)
        if section is None:
            # Fails closed: a silent miss would remove the pointer for every
            # installed user with nothing reporting it.
            out += [
                "agent-guidance's prose-context hook could not quote the "
                "insider-prose rule: " + miss + ". The rule still applies; read "
                "that section of writing_about_code.md directly. The miss is a "
                "plugin bug worth reporting.",
            ]
        else:
            out += [
                "This writes markdown. The rule below, from "
                + root + "/writing_about_code.md, is the one prose written from "
                "inside the work breaks most. Read the draft against it cold.",
                "",
                section,
            ]

    # An unset root is not "scripts/ under the cwd": that would import whatever
    # module of this name the consumer repo happens to carry.
    try:
        if not root:
            raise ImportError
        sys.path.insert(0, os.path.join(root, "scripts"))
        import insider_prose
    except ImportError:
        if out:
            out += ["", "The dangling-reference check did not run: scripts/"
                    "insider_prose.py is missing from " + (root or "an unset GUIDANCE_ROOT") + "."]
        return out

    # Blank a line rather than drop it, so a finding's number stays the line's
    # number in the new text.
    lines = new.splitlines()
    scrubbed = [
        HTML_COMMENT.sub("", ln) if added(ln) else ""
        for ln in lines
    ]
    findings = insider_prose.scan("\n".join(scrubbed))
    if findings:
        where = "the file" if tool == "Write" else "the edit's new text"
        if out:
            out.append("")
        out += [
            "Possible dangling reference: each of these needs its antecedent "
            "in the same text. A firing means check it, not that it is missing.",
            "",
        ]
        for n, _signal, matched in findings[:5]:
            out.append("  line " + str(n) + " of " + where + ": " + matched)
        if len(findings) > 5:
            out.append("  ... and " + str(len(findings) - 5) + " more")
    return out


if ext in MARKDOWN:
    report = markdown()
    if report:
        emit(report)
    sys.exit(0)


# --- source: a tracker key in a code comment ---------------------------------

if not new:
    sys.exit(0)

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
    if not added(line):
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
emit(lines)
