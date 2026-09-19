---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# Source-comment rules live in `portable.md`, not `writing_about_code.md`

## Context

Two issues asked for the same rule in different files, and both cannot hold.
Issue #40 proposed a source-comments section in `writing_about_code.md`, on the
grounds that it is the source of truth for prose conventions and that the
`authoring` and `reviewing` skills both reach it. Issue #45 proposed the
opposite: `writing_about_code.md` should name source comments as out of scope,
because its own opening already disclaims "the code, the identifiers, the file
paths, or quoted output".

A source comment sits on that boundary. It is prose, it is about code, and it
ships inside the code. Nothing in either file said which side it fell on, and
the observed cost of the silence was a nine-line comment duplicating a PR body
plus ticket keys in four comments across three files.

`writing_about_code.md` is also the file both verbs load. A rule placed there
is paid for in every authoring session and every review session, whether or not
the change touches source at all.

## Decision

Source-comment rules live in the Code section of `portable.md`. Both the
one-line budget and the ticket-key prohibition go there, beside the existing
rule about not commenting code you did not change. `writing_about_code.md`
states in its opening that source comments are code rather than communication,
and points at `portable.md` for the budget. Its "Explain the non-obvious"
section names the PR description, the commit body, a design doc and a review
comment as the destinations, so it cannot be read as permission to write the
explanation beside the line it explains.

## Consequences

- Good, because a comment rule sits next to the other rules about what to write
  into a source file, which is where a session writing code is already reading.
- Good, because `writing_about_code.md` keeps one subject, and the two skills
  that load it do not pay for a rule about code.
- Good, because the "explain the non-obvious" instruction now names a
  destination, which was the sentence that read as permission to comment.
- Bad, because a reader looking for every prose rule now checks two files. The
  pointer in `writing_about_code.md` is what makes that survivable.
- Bad, because `portable.md` reaches Codex by concatenation and the rule now
  rides that carrier rather than a skill, so a delivery failure loses it
  silently.

## Revisit when

- `portable.md`'s Code section is split, or the file is reorganised such that
  "what goes in a source file" is no longer one place.
- A second class of in-source prose appears that is plainly communication, and
  the code-versus-communication line stops sorting cases cleanly.

## Confirmation

Nothing mechanical. `scripts/prose-check.py` measures the new text for the
em-dash cap like any other prose in the repo, but no check asserts that the
rule is in this file rather than the other one. That rests on review.

## Alternatives

- **The rule in `writing_about_code.md`, as issue #40 asked:** rejected; it
  contradicts that file's own scope statement, and it taxes both skills for a
  rule about code.
- **The rule in both files:** rejected; a second copy of a convention is the
  thing `reviewing.md` already calls a finding.
