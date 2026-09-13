---
created: 2026-09-13
status: accepted
convention: ../conventions.md
---

# The em-dash cap fails CI; sentence length is reported and never blocks

## Context

Two rules in `writing_about_code.md` are specific enough to measure: at most
one interruption per paragraph, and sentences of about 25 words. Both were in
force for a whole session that broke them continuously (issue #8), and a
rewrite whose purpose was plainer prose halved the sentence count while
leaving the em-dash count untouched. The rule lives in a file read on demand,
and the moment it is most needed is the moment an author is deepest in the
writing and furthest from the rulebook. On 2026-09-13 the corpus broke the
em-dash cap in 12 of 213 paragraphs and the word cap in 30% of sentences,
`writing_about_code.md` itself included.

## Decision

`scripts/prose-check.py` measures every tracked markdown file against both
rules. `prose-check.test.sh` runs it over the repository, so the em-dash cap
fails CI. Sentence length prints a per-file rate and never decides the exit
code. A paragraph is flagged at three em-dashes, not two: one dash is an
interruption and so is a matched pair, and three is the first count that
exceeds one interruption however the dashes pair up.

## Consequences

- Good, because the rule the corpus mostly keeps is enforced where the author
  cannot forget it, and the 12 paragraphs were rewritten in the same change.
- Good, because the charitable count means a firing is a finding, not a
  prompt to disable the check.
- Bad, because the sentence rule is still only reported. A cap the corpus
  breaks at 30% is wrong more often than unheeded, which is what
  `portable.md`'s check-over-prose bullet says to do about it.

## Revisit when

- The sentence-length rate falls far enough that the cap would bind on new
  writing rather than on the backlog; run the script to re-measure.
- The em-dash check fires on a legitimate aside more than occasionally, which
  would mean the floor of three is not charitable enough.

## Confirmation

`prose-check.test.sh`: fixtures for each boundary, then the run over the
repository that makes the em-dash cap bind.

## Alternatives

- **Block on both rules:** fails 30% of existing sentences on day one and
  teaches everyone to ignore the check.
- **Report on both:** leaves the rule that the corpus mostly keeps to the
  same on-demand reading that already failed.
