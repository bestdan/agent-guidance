---
created: 2026-09-13
purpose: conventions for this directory
source: bestdan/agent-guidance dev_docs/designs/README.md
---

# Designs

A design is a proposal for a change that is too big to make without agreeing
on its shape first. It exists to get that agreement, and it is deleted once
the change lands. Nothing here is a description of the system as it is; that
is a convention's job.

## When to write one

Write a design when the change spans more than one PR, touches more than one
subsystem, or makes a choice a reviewer would reasonably question and cannot
judge from a diff alone. For a change smaller than that, make the change; the
PR body carries the reasoning. This is the
[Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/rfcs-and-design-docs)
rule: "For small changes: don't bother. Just make the change."

## What is in one

- **Summary.** The problem and the approach, in a paragraph. A reader who
  stops here knows what is being proposed.
- **What is true today.** The current state, with evidence. Cite a research
  record under `../research/` rather than repeating a survey here.
- **Proposal.** What the change makes true. Interfaces and boundaries over
  implementation detail: say what other parts of the system will see.
- **Decisions.** Each choice the proposal makes, with the alternative it
  rejects and why. These become the decision records on graduation, so write
  each one so it can stand alone.
- **Not decided here.** What the proposal leaves open, so a reviewer does not
  argue about something it does not claim.
- **Graduation.** Which decision records and which conventions this design
  produces when it lands. Filling this in before implementation is what makes
  the deletion at the end mechanical.

Include what has material impact on whether the proposal is accepted, and no
more. The [Fuchsia RFC guidance](https://fuchsia.dev/fuchsia-src/contribute/governance/rfcs/best_practices)
gives the test: would changing this detail change a reviewer's verdict, and
should the reviewer be told if the implementation diverges from it? If neither,
leave it to the PR.

## Naming and front matter

`YYYY-MM-DD-<slug>.md`, kebab-case. The date is when the design was written
and matches `created`.

A record that carries artifacts — the script that measured something, the
capture it read, the numbers it produced — becomes `YYYY-MM-DD-<slug>/` with
the design as its `README.md` and the artifacts under `references/`. The rules
above are unchanged; the date moves to the directory. `dev_docs_layout.md` at
the plugin root has the shape and what does not belong there.

The fields are unchanged; a relative path inside one is not. It resolves from
a file one level deeper, so a link to `../research/<name>.md` becomes
`../../research/<name>.md`, and so does every other `../` in the body.

A design's artifacts are as transient as the design: the prototype that proved
the shape is deleted with it, and anything worth keeping has graduated into
real code by then.

```yaml
---
created: 2026-09-13
status: proposed
tracks: https://github.com/<owner>/<repo>/issues/<n> # the plan, issue, or PR implementing it; omit until one exists
---
```

`proposed` is the only status. Merging the design is the agreement to build
it; a design that is not agreed is closed with its PR and never lands. A
design that is agreed and then abandoned is deleted with a PR whose body says
why, and if the reason is worth keeping it becomes a decision record.

## Lifecycle: graduate, then delete

A design is deleted in the PR that finishes implementing it, or the one right
after. Before deleting:

1. Write one decision record under `../decisions/` per choice in the
   **Decisions** section that someone could want to revisit.
2. Move what a reader needs in order to work with the result into a
   convention: a `dev_docs/<topic>.md`, or the repo's `AGENTS.md`.
3. Delete the design. Link to the PR that merged it from the decision records
   if the discussion there matters.

A design still present after its change has landed is residue, and the next
reader cannot tell whether it describes the system or a plan that changed on
the way. Never link a design from code or a convention to explain how
something works; link the convention, and let the convention cite the
decision.

## Template

```markdown
---
created: YYYY-MM-DD
status: proposed
---

# <Title naming the change>

<Summary: the problem and the approach, one paragraph.>

## What is true today

<Current state, with evidence. Cite ../research/ records rather than repeating them.>

## Proposal

<What the change makes true. Boundaries and interfaces over detail.>

## Decisions

### <Choice>

<What is chosen, the alternative rejected, and why. Written so it can become a decision record.>

## Not decided here

- <What this leaves open.>

## Graduation

- Decision records: <one line per record to write on landing>
- Conventions: <the live file(s) that receive the guidance>
```
