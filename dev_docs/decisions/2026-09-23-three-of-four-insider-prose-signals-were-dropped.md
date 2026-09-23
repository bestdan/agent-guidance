---
created: 2026-09-23
status: accepted
convention: ../../writing_about_code.md
---

# Three of four insider-prose signals were dropped, and the fourth only reports

## Context

Four regex signals were designed for insider prose, and fixtures were written
before any pattern: the two examples from #62 verbatim, two further bad cases,
and correct rewrites of three of them. A signal that fires on a correct
rewrite is worse than one that misses, because its reader learns to skip it.

The tracked corpus could not decide between them. All four returned zero hits
across the 46 tracked markdown files, so every drop below came from a good
case the corpus could never have surfaced.

## Decision

Three signals were dropped before implementation, each on a good case it
fires on:

- **Two or more bare `N/M` ratios in a sentence.** It missed the #62 example
  it was written for. A following-word test reads "14/14 in" as carrying a
  unit, exactly as it correctly reads "1/2 cup", and telling those apart needs
  a unit vocabulary.
- **`(rule|section|step|candidate|option) N` in a first paragraph.** It fires
  on "Step 1 installs the dependencies."
- **A chronology opener in a first sentence.** It fires on "Initially, the
  buffer is empty."

The fourth, a `the same N <noun>`, was kept and reports without ever failing.
It also fires on three shapes of correct prose: a following relative clause
(`It reads the same 14 rows the baseline read`), a comparison in the sentence
(`Both machines resolve the same 2 paths`), and an earlier mention of the
quantity. No separating mechanism exists: the first shape is string-identical
to a dangling one within the window a regex sees, and what tells them apart is
whether the clause before the match already has its verb, which is a parse.

## Consequences

- Good, because the one surviving signal caught its target example, and it
  costs 0.44 ms riding an interpreter the pointer already starts.
- Bad, because it fires on correct prose, which is the failure the fixtures
  existed to catch. It survives only because it prints a line and never fails
  a build, so a false firing costs a reader's glance.
- Bad, because historical narrative has no mechanical tier at all.

## Revisit when

- Firings become routine on ordinary writes. The cost of an imprecise signal is
  paid per firing, so the consistent answer then is to drop it, not to tune it.
  `hooks/prose-context.sh` is what makes firings visible.
- `bestdan/dotfiles` `guard_pr_body.py` adopts the pattern as a denial
  (bestdan/dotfiles#914) and its escape marker gets used on correct bodies.

## Confirmation

`insider-prose.test.py` asserts that the good rewrites and the inline-code case
stay silent, and that the #62 example (bad-2) fires. A pattern change that
widens onto a correct rewrite, or narrows past that example, fails the suite.
The other bad cases and the three false-positive shapes are printed as notes
and not asserted. `prose-check.py` keeps the signal in its
reporting tier beside sentence length, not its failing tier beside the em-dash
cap.

## Alternatives

- **Fail the build on the signal:** rejected; it cannot tell a dangling
  reference from a resolved one, so failing would fail correct prose.
- **Keep the pointer and no signal at all:** the fallback, and still live under
  the first revisit condition.
