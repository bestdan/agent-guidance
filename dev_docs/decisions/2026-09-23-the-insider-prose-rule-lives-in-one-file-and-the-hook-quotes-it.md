---
created: 2026-09-23
status: accepted
convention: ../../writing_about_code.md
---

# The insider-prose rule lives in one file, and the hook quotes it at run time

## Context

Issue #62 reported two PR bodies written from inside the work: one recounting
how the work unfolded, one whose clauses sent the reader looking things up.
`writing_about_code.md` and `authoring_pull_requests.md` already forbade both
shapes, and both files were loaded in the session that produced the examples.
Guidance that is in context and unfollowed is not fixed by a second copy of it.

Two readers need the rule: the writer, and the reviewer. `skills/authoring` and
`skills/reviewing` both read `writing_about_code.md` as their first step. A
third carrier, the `PreToolUse` hook, fires on a markdown write without either
skill loaded.

`hooks/prose-context.py` already carried a hardcoded quote of `portable.md` for
the tracker-key check. A second hardcoded quote beside it would make drift
between the hook and the rule the default.

## Decision

The rule is stated once, as the `## Don't write insider prose` section of
`writing_about_code.md`. `reviewing.md` carries a one-line pointer to it under
`## What a review checks` and restates nothing. The hook reads the section out
of the file at run time through `GUIDANCE_ROOT`, which its wrapper exports, and
quotes it once per session on the first markdown write. The read fails closed:
a missing file, an unset root, or a heading that matches zero times or more
than once produces a message naming the miss instead of silence.

## Consequences

- Good, because writer, reviewer and hook reach one set of bytes, so the three
  cannot disagree about what the rule says.
- Good, because no test has to assert that one sentence appears in two files,
  an assertion about prose that this suite otherwise never makes.
- Bad, because renaming the heading breaks the hook. The fail-closed message
  makes that loud in every session, and `prose-context.test.sh` fails first
  because it runs the real hook against this repo's own file.
- Bad, because the quote costs its section's tokens once per session whether or
  not the session writes prose worth checking.

## Revisit when

- The token cost of the quote is measured and outweighs what it catches.
- A harness other than Claude Code gains a pre-write hook and needs the rule
  without a plugin root to read it from.

## Confirmation

`prose-context.test.sh`, section 14: the first markdown write quotes the
heading and the section's body, stops at the next `##` heading, and names the
file it read. Three further cases pin the fail-closed messages for a missing
file, a renamed heading and a duplicated one.

## Alternatives

- **A fourth prose file linked from the other three:** rejected; the failure in
  #62 was not re-reading, and a file one link further away is read less.
- **A hardcoded quote in the hook, held equal by a test:** rejected; it would be
  the first assertion in this suite about prose rather than wiring.
