---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# Conventions, decisions, and designs are three different things

## Context

`dotfiles` kept everything in `designs/`, including standing decisions and
machine-readable data. `workflow-skills` had `decisions/` for measurements
and `designs/` for proposals, with `workflow-review/` beside them, and no
stated boundary. A reader could not tell from the path whether a file was
guidance, history, or a plan.

## Decision

A convention says what to do and is live; an agent reads conventions to work
and never has to open a decision. A decision says why, at the time, and what
would reopen it, and is a record. A design proposes a change and is
transient: only ever `proposed`, deleted once its change lands, its choices
graduating into decisions and what a reader needs into conventions. Research
is a separate record kind that feeds designs and decisions with evidence.

## Consequences

- Good, because each reader gets the file written for them: the worker gets
  the convention, the revisiter gets the decision, the reviewer gets the
  design.
- Good, because a design cannot rot into a false description of the system;
  it is gone before it can.
- Bad, because graduation is a step that has to be done, and the survey
  shows graduate-then-delete was written down before and honoured nowhere.
  The design template's Graduation section exists to make it mechanical.

## Revisit when

- Designs are found still present after their changes land, which means the
  transient rule is not being followed and needs a check rather than a
  convention.
- A design's history turns out to be wanted as a whole rather than as its
  decisions, which would argue for keeping accepted designs as records.

## Confirmation

Review, and the layout test's residue check once the shared checker exists.

## Alternatives

- **`designs/` doing all three jobs:** the `dotfiles` shape; guidance and
  history are indistinguishable.
- **Keeping accepted designs as historical records:** Fuchsia's RFC model.
  Rejected because the history a design carries is its decisions, better
  kept one per file where each can be superseded alone.
