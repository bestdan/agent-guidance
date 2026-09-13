---
created: 2026-09-13
status: proposed
tracks: https://github.com/bestdan/agent-guidance/pull/31
---

# One `dev_docs/` layout for every repo

Four repos use `dev_docs/` and no two agree on what goes where. This design
fixes one layout, states the rule it follows from, gives each directory its
own README with a template, and lists what each repo changes to match. The
convention ships in this plugin as `dev_docs_layout.md`, reached by name from
`portable.md`, so it arrives in every session the way the reviewing and
authoring conventions do.

Nothing here changes tooling. `workflow-skills` keeps ownership of
`dev_docs/tasks/` and of research-spike trees under `dev_docs/research/`.

## What is true today

The survey is `../research/2026-09-13-dev-docs-survey.md`. In short: the only
consistent directory is `.handoffs/`; `designs/` and `decisions/` have no
stated boundary and both hold standing decisions, measurement records, and
data; about half the records are dated, with prefix dates in most directories
and suffix dates in one; slug case varies within single directories; status
lives in prose that nothing can check; graduate-then-delete is written down
and honoured nowhere; skill config under `dev_docs/` uses three ignore
channels and one machine-local file is tracked as a result; no repo has a
`dev_docs/README.md`.

The format research is `../research/2026-09-13-adr-and-design-templates.md`.

## Proposal

`dev_docs_layout.md` at the plugin root is the umbrella: the record/live rule,
the three kinds of knowledge, the directory table, naming, and what never
goes there. Each directory carries a `README.md` with that directory's rules
and template. This repo holds the canonical READMEs for `designs/`,
`decisions/`, and `research/`, beside the `.handoffs/README.md` that already
exists; other repos copy the ones they use, each copy naming its source.

## Decisions

### The record/live split is the organising rule

A file with a date in its name is a record and may go stale; a file without
one is live and must not. `dotfiles`' state-locality design and `portable.md`
already state this; what is new is laying the directories out on it, so the
path alone says which kind of file is in hand. The alternative, a README per
directory each stating its own rules with no shared principle, is what
`.handoffs/` does today, and three diverging copies of that README show where
it stops.

### Conventions, decisions, and designs are three different things

A convention says what to do and is live. A decision says why, at the time,
and what would reopen it, and is a record. A design proposes a change and is
transient. An agent reads conventions to work; it reads decisions only to
revisit one; it reads a design only to review it.

Rejected: `designs/` doing all three jobs (the `dotfiles` shape) and
`decisions/` as a place for measurements (the `workflow-skills` shape). Both
leave a reader unable to tell from the path whether a file is guidance,
history, or a plan.

### Designs are transient and only ever `proposed`

A design's job ends when its change lands. It then graduates: each choice it
argued for becomes a decision record, what a reader needs becomes a
convention, and the design is deleted. A landed design that stays is residue
that reads as either a description of the system or a plan that changed on
the way, and the next reader cannot tell which.

Rejected: keeping designs as accepted historical records, which is what
Fuchsia's RFC process does. The history a design carries is its decisions,
and those are better kept one per file where each can be superseded alone.

### Decisions are ADRs with a "revisit when" section

Nygard's four sections and immutability rule, MADR's consequence phrasing and
confirmation section, plus a required section naming the evidence that would
reopen the decision. No surveyed format has that section; it is the stated
purpose of keeping the record, so it is required rather than optional.
`accepted` is the starting status, because a decision is written once taken;
an open choice is a design.

Rejected: MADR's `NNNN-` numbering, since the date is already the sort key
everywhere under `dev_docs/`; MADR's people fields, since the PR carries the
reviewer.

### Research is its own record, cited from designs and decisions

A survey or a comparison goes in `research/` as a dated record with a
`question` and a `feeds` pointer, and the design cites it. This keeps designs
to material impact and keeps evidence readable without the conclusion beside
it. Research-spike trees from `workflow-skills` live as subdirectories of the
same `research/` and keep the skill's conventions.

### Each directory carries its own README and template

How to write a decision is not how to write a design, so the rules and the
template sit in the directory they govern, where the writer is. The umbrella
file stays short. The cost is copies across repos, each marked with its
source, which is the same trade `.handoffs/README.md` already made.

### Date first, kebab-case, no type suffix

Prefix dates so a listing sorts by time and a stale file is visible.
Kebab-case because it is the majority form in every record directory
surveyed. `tasks/` stays snake_case because its tooling fixes the form.

### Records carry front matter

`created` and `status` at minimum, with the supersede pointers. Prose status
lines cannot be checked; a `created` that must match the filename date is a
test. This is the one decision that costs a migration.

### `tasks/` ignore policy follows the handler

Under `repo-pr` the cards are the tracker and are committed. Under any other
handler the tracker owns the state and the scaffolding is local, which is the
`workflow-skills` `.gitignore` shape. `dotfiles` tracking plans under
`gh-issue` is the inconsistency.

### One ignore channel for skill config: `.gitignore`

`.git/info/exclude` does not travel with a clone, so a fresh checkout cannot
know a directory is local until the skill runs. `.gitignore` is visible and
doubles as documentation. The tracked `.coders.yml` in `papercuts-plugin` is
what the other channel produced.

### The convention lives in this plugin

Delivered like `writing_about_code.md`: a root content file, reached by name
from a `portable.md` Rules bullet, so it reaches every harness and every
cloud session without a consumer repo committing it. The per-directory
READMEs are the one part that is copied, because they have to sit in the
directory they govern.

## Not decided here

- The shared layout checker: its shape and where a repo calls it from.
  `dotfiles/scripts/dev_docs_layout.test.sh` stays the reference until then.
- Whether a `<name>_plan/` may hold non-card files. The task tooling
  tolerates them; `plan-with-docs` says to delete them. That is a
  `workflow-skills` question.

## Migration

Each item is a follow-up in its repo.

**`agent-guidance`:** graduate this design once merged: write the decision
records listed below, delete this file. The 2026-09-12 design's three
decisions are already records under `decisions/`.

**`dotfiles`:** date and front-matter every design; delete the ones whose
changes have landed after writing their decisions; rename
`papercuts_reports/` files to date-first; move the rule inventory out of
`designs/`; ignore `dev_docs/tasks/*` except `.task-config.yml` and run the
graduate-then-delete the three finished plans schedule; add
`dev_docs/README.md` and the directory READMEs; extend the layout test with
the two new checks; drop the stale `nightly_reports/` citation in `justfile`.

**`workflow-skills`:** sort `decisions/` into decisions and conventions, and
`designs/` and `workflow-review/` into designs still proposed and
conventions; date and front-matter what stays; move
`research/research-spike-lean-evaluation.md` to a research record; delete
`tasks/autopilot_hardening_plan/` and finish `cao_usage_plan`'s graduation;
point `orchestrate-coders` at `.gitignore`; add `dev_docs/README.md` and the
directory READMEs.

**`papercuts-plugin`:** untrack `dev_docs/orchestrate-coders/.coders.yml` and
ignore the directory; graduate or front-matter the one design; add
`dev_docs/README.md`; resolve the handoff whose milestones have closed.

## Graduation

- Decision records: the record/live rule; three kinds of knowledge; designs
  transient; decisions as ADRs with revisit-when; research as its own record;
  per-directory READMEs; naming; front matter on records; `tasks/` ignore
  policy; one ignore channel for skill config; the convention lives in the
  plugin.
- Conventions: `dev_docs_layout.md` and the three directory READMEs are
  already the live guidance; graduation adds nothing to them beyond replacing
  the pointer to this design with pointers to the decisions.
