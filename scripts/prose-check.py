#!/usr/bin/env python3
"""Measures this repo's markdown against two rules from writing_about_code.md.

Run: scripts/prose-check.py [path ...]

With no argument it reads every tracked *.md. Only the em-dash cap decides the
exit code; sentence length is reported and never fails. That split is measured,
not a preference: at the time the check landed 6% of paragraphs broke the
em-dash cap and 30% of sentences ran over the word cap, and a rule most of the
corpus already breaks is wrong more often than unheeded.

Both counts are deliberately charitable, so a firing is a finding rather than a
prompt to disable the check.
"""

import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import insider_prose  # noqa: E402  (path set above)

WORD_CAP = 25  # portable.md, Simplified Technical English: 25 words in a description.
EM_DASH = "—"

# One em-dash is an interruption; a matched pair bracketing an aside is also one.
# n dashes are therefore at least ceil(n / 2) interruptions, so 3 is the first
# count that exceeds the cap of one however the dashes pair up.
EM_DASH_FLOOR = 3

_FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
_SKIP_LINE = re.compile(r"^(?:#|\||>?\s*[-=]{3,}$|\[[^\]]+\]:\s)")
_INLINE_CODE = re.compile(r"`[^`]*`")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_BULLET = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
_SENTENCE_END = re.compile(r"(?<=[.!?])[\"')\]]?[*_~]*\s+(?=[*_~]*[A-Z\"'(\[])")
_WORD = re.compile(r"[A-Za-z0-9]")

# A sentence never ends here, whatever follows looks like a capital.
ABBREVIATIONS = ("e.g.", "i.e.", "etc.", "vs.", "cf.", "Mr.", "Ms.", "Dr.", "No.")


def paragraphs(text):
    """Yield (line_number, paragraph_text) for each prose block.

    Fenced code, tables, headings, and link reference definitions are not prose
    and are dropped. A paragraph runs to the next blank line, and a list item
    also starts one: a tight list is a list however it is spaced, and treating
    one as a single paragraph charges a 50-bullet file one cap for the lot.
    """
    lines = text.split("\n")
    fence = None
    start = 0
    current = []
    for number, line in enumerate(lines, 1):
        match = _FENCE.match(line)
        closes_fence = match and fence is not None and (
            match.group(1)[0] == fence[0] and len(match.group(1)) >= fence[1]
        )
        if match and (fence is None or closes_fence):
            if fence is None:
                fence = (match.group(1)[0], len(match.group(1)))
            else:
                fence = None
            if current:
                yield start, " ".join(current)
                current = []
            continue
        if fence is not None:
            continue
        stripped = line.strip()
        if not stripped or _SKIP_LINE.match(stripped) or _BULLET.match(line):
            if current:
                yield start, " ".join(current)
                current = []
            if not stripped or _SKIP_LINE.match(stripped):
                continue
        if not current:
            start = number
        current.append(stripped)
    if current:
        yield start, " ".join(current)


def sentences(paragraph):
    """Split a paragraph into sentences, with markup that inflates counts removed."""
    text = _INLINE_CODE.sub("CODE", paragraph)
    text = _LINK.sub(r"\1", text)
    text = _BULLET.sub("", text)
    out = []
    for part in _SENTENCE_END.split(text):
        if out and out[-1].endswith(ABBREVIATIONS):
            out[-1] = out[-1] + " " + part
        else:
            out.append(part)
    return [part.strip() for part in out if part.strip()]


def prose_text(paragraph):
    """Remove markup that is not visible prose while retaining link labels."""
    text = _INLINE_CODE.sub("CODE", paragraph)
    return _LINK.sub(r"\1", text)


def word_count(sentence):
    return sum(1 for token in sentence.split() if _WORD.search(token))


def measure(path):
    """Return (long_sentences, sentence_total, em_dash_violations, dangling).

    A violation is (line_number, em_dash_count); a long sentence is
    (line_number, word_count, sentence); a dangling reference is
    (line_number, matched_text).
    """
    text = pathlib.Path(path).read_text(encoding="utf-8")
    long_sentences = []
    violations = []
    total = 0
    for line, paragraph in paragraphs(text):
        dashes = prose_text(paragraph).count(EM_DASH)
        if dashes >= EM_DASH_FLOOR:
            violations.append((line, dashes))
        for sentence in sentences(paragraph):
            total += 1
            count = word_count(sentence)
            if count > WORD_CAP:
                long_sentences.append((line, count, sentence))

    # Scanned over the paragraph stream, not the raw file, so the fenced
    # blocks and tables `paragraphs()` already drops stay dropped: a bad
    # example quoted inside a fence is not prose this rule governs.
    #
    # Paragraph-start is the granularity, as it is for the two rules above.
    # `paragraphs()` joins a paragraph's lines with a space, so what reaches
    # the detector never carries a newline and its own line numbers are always
    # 1; reporting them would claim a precision this stream cannot supply.
    dangling = []
    for line, paragraph in paragraphs(text):
        for _offset, _signal, matched in insider_prose.scan(paragraph):
            dangling.append((line, matched))

    return long_sentences, total, violations, dangling


def tracked_markdown():
    result = subprocess.run(
        ["git", "ls-files", "-z", "*.md"],
        capture_output=True,
        check=True,
    )
    return [path.decode("utf-8") for path in result.stdout.split(b"\0") if path]


def main(argv):
    paths = argv[1:] or tracked_markdown()
    if not paths:
        print("prose-check: no markdown to check", file=sys.stderr)
        return 1

    all_violations = []
    all_dangling = []
    long_total = 0
    sentence_total = 0
    rows = []
    for path in sorted(paths):
        long_sentences, total, violations, dangling = measure(path)
        long_total += len(long_sentences)
        sentence_total += total
        all_violations.extend((path, line, count) for line, count in violations)
        all_dangling.extend((path, line, matched) for line, matched in dangling)
        rows.append((path, len(long_sentences), total))

    print(f"sentences over {WORD_CAP} words (reported, never fails):")
    for path, long_count, total in rows:
        share = f"{100 * long_count / total:.0f}%" if total else "-"
        print(f"  {long_count:4d}/{total:<4d} {share:>4}  {path}")
    share = f"{100 * long_total / sentence_total:.0f}%" if sentence_total else "-"
    print(f"  {long_total:4d}/{sentence_total:<4d} {share:>4}  TOTAL")

    # Reported and never failing, for the reason the module's docstring gives:
    # the signal says "go check the antecedent" and cannot say "there is none",
    # so a resolved reference matches it exactly as a dangling one does. The
    # em-dash cap below can decide a violation, which is why that one fails.
    print()
    print("references to check (reported, never fails):")
    if not all_dangling:
        print("  none")
    for path, line, matched in all_dangling:
        print(f"  {path}:{line}  {matched}")

    print()
    if not all_violations:
        print("em-dash cap: no paragraph carries more than one interruption")
        return 0

    print("em-dash cap exceeded (writing_about_code.md, Voice):")
    for path, line, count in all_violations:
        print(f"  {path}:{line}  {count} em-dashes in one paragraph")
    print()
    print(
        f"FAIL: {len(all_violations)} paragraphs over the cap of one em-dash "
        "interruption. Rewrite the aside, or split the sentence."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
