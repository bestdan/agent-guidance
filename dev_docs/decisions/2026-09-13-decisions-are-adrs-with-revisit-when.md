---
created: 2026-09-13
status: accepted
convention: ../decisions/README.md
---

# Decision records are ADRs with a required "revisit when" section

## Context

The stated purpose of keeping a decision is to know later what would change
it. The surveyed formats
(`../research/2026-09-13-adr-and-design-templates.md`) give Nygard's four
sections and immutability rule, and MADR's consequence phrasing and
confirmation section, but none has a section for what would reopen the
decision. MADR also numbers files `NNNN-` and carries people fields.

## Decision

A decision record has Context, Decision, Consequences ("Good, because",
"Bad, because"), a required Revisit when, Confirmation, and optional
Alternatives. It is named `YYYY-MM-DD-<slug>.md`, starts at `status:
accepted` because it is written once taken, and is never rewritten: it is
superseded, deprecated, or annotated with a dated callout.

## Consequences

- Good, because the section that answers "should we change this?" is the one
  the format requires, and "never" is only accepted with a reason.
- Good, because the date is the sort key everywhere under `dev_docs/`, so no
  second sequence has to be kept unique.
- Bad, because a record without a real revisit condition will get a
  perfunctory one; review has to read that section as the test of whether the
  decision was worth recording.

## Revisit when

- Records accumulate perfunctory "never" entries, which would mean the
  section is not doing its job.
- More than one author works a repo, which is when MADR's people fields earn
  their place.

## Confirmation

Review against `decisions/README.md`. A checker could require the section
heading; that is part of the shared-checker follow-up.

## Alternatives

- **MADR `NNNN-` numbering:** a second sequence beside the date.
- **A `proposed` status for decisions:** an open choice is a design, not a
  decision.
