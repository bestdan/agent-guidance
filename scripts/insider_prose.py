"""Detects one shape of insider prose: a dangling `the same N <noun>`.

Pure: no I/O, no side effects, no knowledge of who is calling. The caller
decides what text to hand it -- the hook passes the lines a write adds,
`prose-check.py` passes a whole file -- and gets back the same findings either
way. The rule it serves is the `## Don't write insider prose` section of
`writing_about_code.md`, which is the only place the rule's text lives.

**This reports; it never decides.** The regex cannot see antecedents, so a
firing means "go check the antecedent" and never "there is none". "The baseline
covered 14 rows. The candidate covered the same 14 rows." matches and is
correct prose. That is why `prose-check.py` carries this in its reporting tier
beside sentence length rather than in the failing tier beside the em-dash cap:
the em-dash cap can decide a violation and this cannot.

Only one signal survived design. Three others -- a pile-up of bare ratios, a
numbered cross-reference in a first paragraph, and a chronology opener in a
first sentence -- each fired on ordinary technical prose and were dropped
before implementation. The other shape the rule names, historical narrative, is
a judgment no regex reaches; the hook's once-per-session pointer carries it.
"""

import re

# A demonstrative quantity with a noun: "the same 14 rows", "The same 3 files".
# Case-insensitive because it lands at a sentence start as often as mid-clause.
# The noun is required -- a bare "the same 14" is usually a fragment mid-edit
# rather than prose, and charging it would fire on text nobody has finished
# writing.
SAME_N = re.compile(r"\bthe same \d+ \w+", re.IGNORECASE)

# Matches prose-check.py's `_INLINE_CODE`, deliberately: the two consumers
# should disagree about what counts as prose as little as possible, and that
# file is where the treatment already exists.
INLINE_CODE = re.compile(r"`[^`]*`")


def strip_inline_code(line):
    """Blank out inline-code spans that pair within this line.

    Best-effort, and it has to be. A hook sees the lines a write adds, and an
    added line can begin or end mid-span -- CommonMark lets a code span cross a
    line ending, and an `Edit` cuts wherever the edit cut. A single unmatched
    backtick therefore leaves its span unstripped rather than swallowing the
    rest of the line, which is the failure direction that costs a missed
    finding instead of a wrong one.

    `prose-check.py` reads whole files and additionally drops fenced blocks,
    which needs the document. Nothing here can see a fence: an added line
    inside one is indistinguishable from an added line outside it.
    """
    return INLINE_CODE.sub("CODE", line)


def scan(text):
    """Return [(line_number, signal, matched_text)] for each firing.

    Line numbers are 1-based within `text`, so the caller maps them onto the
    file: they are file lines for a whole-file read and positions within the
    added block for a hook.
    """
    findings = []
    for number, line in enumerate(text.splitlines(), 1):
        prose = strip_inline_code(line)
        for match in SAME_N.finditer(prose):
            findings.append((number, "dangling-reference", match.group(0)))
    return findings
