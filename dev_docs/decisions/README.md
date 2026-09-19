---
created: 2026-09-13
purpose: conventions for this directory
source: bestdan/agent-guidance dev_docs/decisions/README.md
---

# Decisions

One decision per file: what was decided, why, and what would reopen it. A
decision record is reference material for the future reader who is about to
revisit the choice. It is not guidance for the reader who wants to know what
to do today; that reader gets a convention, which is the live file the
decision supports.

The format is an architecture decision record (ADR) in the sense
[Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
gave it, with the consequences and confirmation sections
[MADR](https://adr.github.io/madr/) adds. The evidence behind the choices in
this file is in `dev_docs/research/2026-09-13-adr-and-design-templates.md`.

## When to write one

Write a decision when a choice has a reason worth keeping and someone could
plausibly want to reverse it later. The sharpest test is the reader in a year
who asks "why is it like this?" and would otherwise have to guess. A choice
that the code makes obvious, or that nobody would revisit, needs no record.

A design that lands produces decisions: each choice the design argued for
becomes one record, written when the design is deleted (see
`../designs/README.md`). A decision can also stand alone, when the choice
was small enough to make without a design.

## What is in one

- **Context.** The forces at play, stated neutrally: the constraint, the
  measurement, the failure that prompted this. Enough that a reader can tell
  whether the forces still hold.
- **Decision.** What was chosen, in the active voice. One paragraph.
- **Consequences.** What follows, good and bad, each tied to the context.
  "Good, because …", "Bad, because …".
- **Revisit when.** The evidence that would reopen this: a measurement
  crossing a line, a dependency going away, a constraint lifting. This is the
  section that makes the record useful later, so it is required, and "never"
  is an acceptable answer only with a reason.
- **Confirmation.** How the decision is held up: a test, a hook, a review
  rule, or nothing. Optional, but say "nothing" rather than omitting it, so a
  future reader knows the decision rests on convention alone.
- **Alternatives**, when they were live: one line each on what was rejected
  and why. Optional; a decision made against no real alternative has none.

Aim for one page. A decision that needs more is usually carrying a design,
and the design belongs in `../designs/` while it is proposed.

## Naming and front matter

`YYYY-MM-DD-<slug>.md`, kebab-case. The date is when the decision was taken
and matches `created`. Dates rather than MADR's `NNNN-` numbers, because the
date is the sort key everywhere else under `dev_docs/` and a number adds a
second sequence to keep unique.

A record that carries artifacts — the script that measured something, the
capture it read, the numbers it produced — becomes `YYYY-MM-DD-<slug>/` with
the decision as its `README.md` and the artifacts under `references/`. The rules
above are unchanged; the date moves to the directory. `dev_docs_layout.md` at
the plugin root has the shape and what does not belong there.

```yaml
---
created: 2026-09-13
status: accepted # accepted | superseded | deprecated
supersedes: 2026-08-01-old-name.md # when this replaces an earlier decision
superseded_by: 2026-10-02-newer-name.md # set on the old record when replaced
convention: ../conventions.md # the live file this decision supports, if any
---
```

A decision is written once it is taken, so `accepted` is the starting state
and there is no `proposed`. A choice that is still open is a design.

## Lifecycle

A decision is never rewritten. Three changes are allowed, and only these:

- **Superseding.** A new decision replaces this one: the new record carries
  `supersedes:`, this one gets `status: superseded` and `superseded_by:`. The
  rest of this file stays as written.
- **Deprecating.** The decision no longer applies and nothing replaces it:
  `status: deprecated` plus a dated callout at the top saying why.
- **A dated callout** for information that arrived after the decision and
  does not change it: `> [!NOTE] 2026-10-02: …`.

Which one applies: if a reader who acted on this record would now do
something different, supersede or deprecate. Otherwise a callout.

## Template

```markdown
---
created: YYYY-MM-DD
status: accepted
convention:
---

# <Short title naming the problem and the choice>

## Context

<The forces: constraints, measurements, the failure that prompted this.>

## Decision

<What was chosen, active voice, one paragraph.>

## Consequences

- Good, because <effect, tied to the context>.
- Bad, because <cost, tied to the context>.

## Revisit when

- <The evidence that reopens this.>

## Confirmation

<The test, hook, or review rule that holds this up, or "nothing".>

## Alternatives

- **<Option>:** <why not, one line.>
```
