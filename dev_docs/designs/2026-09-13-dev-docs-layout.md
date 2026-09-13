---
created: 2026-09-13
status: proposed
live: ../../dev_docs_layout.md
---

# One `dev_docs/` layout for every repo

> Dated design record. The live convention is [`dev_docs_layout.md`](../../dev_docs_layout.md) at the plugin root; where the two disagree, that file is current and this one is history.

Four repos use `dev_docs/` and no two agree on what goes where. This design
fixes one layout, states the rule the layout follows from, and lists what each
repo changes to match. The convention ships as a content file in this plugin,
reached by name from `portable.md`, so it arrives in every session the way the
reviewing and authoring conventions do.

**Nothing here changes tooling.** `workflow-skills` keeps ownership of
`dev_docs/tasks/` and `dev_docs/research/`; this design takes those two
directories as given and lays out everything around them.

## What is true today

Surveyed 2026-09-13 across `agent-guidance`, `dotfiles`, `workflow-skills`,
and `papercuts-plugin`. Paths are as found.

**The only consistent directory is `.handoffs/`.** All three repos that have
it share a `README.md` copied from `dotfiles`, with the same naming rule
(`YYYY-MM-DD-<short-topic>.md`), the same front matter, and the same
ignored-twice mechanism. That README is the only written convention in any of
the four repos, and it covers one directory.

**`designs/` and `decisions/` have no stated boundary.**

- `dotfiles` has `designs/` only. Several files there are standing decisions
  by their own status line ("accepted on merge — merging this document is the
  decision"), and one, `2026-09-05-agents-md-rule-inventory.md`, is
  machine-readable data with a YAML head, not a design.
- `workflow-skills` has both. `decisions/` holds measurement records
  (`python_type_checking.md`: "Measured 2026-09-04"); `designs/` holds
  proposals. Nothing says which is which, and `workflow-review/` sits beside
  them holding what reads as more designs.
- `papercuts-plugin` has `designs/` only, and its one design says "merging
  this document is the decision".

**Dating is applied to about half the records.** `dotfiles/designs/` is dated
except `claude-settings-portable-sync-design.md`; `workflow-skills/decisions/`
is 3 of 8 dated and `designs/` 1 of 5. `dotfiles/papercuts_reports/` dates its
files as a suffix (`papercuts_triage_2026-07-20.md`) while every other
directory uses a prefix. `portable.md` already says "a file that records a
moment must carry its date in the filename or path", so this is a rule that
exists and is not followed.

**Slug case is unsettled inside single directories.**
`workflow-skills/decisions/` mixes `linear_read_fastpaths.md` with
`2026-09-05-cloud-session-plugin-and-proxy.md`; `designs/` mixes
`research_spike_skill.md` with `auth-key-resolution.md`.

**Records carry status as prose, and only `tasks/` and `.handoffs/` use front
matter.** Designs open with `**Status:** proposed` or `Date: 2026-08-01`,
`Supersedes: …` as body lines. Nothing can check them. Amendment is done two
ways: `dotfiles/designs/2026-09-04-agents-md-context-budget.md` is amended in
place with a dated callout; `papercuts_oss_task_11_assessment.md` supersedes an
earlier draft by saying so in prose.

**`tasks/` is tooling-owned and the tooling is consistent; the repos are
not.**

- Ignore policy differs: `workflow-skills` ignores `dev_docs/tasks/*` except
  `.task-config.yml`; `dotfiles` tracks its plan directories under a
  `gh-issue` handler; `papercuts-plugin` tracks `.task-config.yml` in an
  otherwise empty directory.
- Graduate-then-delete is written in `skills/plan-with-docs` and honoured
  nowhere: `workflow-skills/tasks/autopilot_hardening_plan/` holds 26 cards
  marked `done` beside the graduated `dev_docs/auto-pilot-hardening.md`;
  `dotfiles` has three plans whose final card is "delete this directory", all
  still present.
- `dotfiles/tasks/cmux_session_checkpoint_plan/` holds only a `design.md`, and
  `papercut-dotfiles-dir_plan/` only a dated, front-matter-less checkbox plan.
  Both pass the layout test, which checks the directory name and nothing
  inside it.

**Skill config under `dev_docs/` uses three ignore channels.** `co-review`
appends to `.gitignore`, `orchestrate-coders` to `.git/info/exclude`,
`/task-config` uses a local exclude for tracker handlers. The failure it
produces: `papercuts-plugin/dev_docs/orchestrate-coders/.coders.yml` is
tracked, and it is a machine-local probe result (`installed: false` for two
backends, an auth choice) that is wrong on every other machine.

**`research/` is misused once.** `workflow-skills/dev_docs/research/` holds a
single flat document, not the `<project>/` tree the `research-spike` skill
scaffolds. `scripts/check.sh` says the repo does not gate on that tree at all,
and the skill's own documentation notes that "no research dir" and "wrong tree
scanned" produce identical clean output, so the stray file is unchecked.

**No repo has a `dev_docs/README.md`.** `papercuts-plugin` has no `AGENTS.md`
either, so its layout is undocumented for a reader at the root.
`workflow-skills`' `AGENTS.md` carries a routing table and `dotfiles`'
carries pointers; neither describes the directories.

## Decisions

### The record/live split is the organising rule

Everything else follows from one distinction: a file with a date in its name
is a record and may go stale; a file without one is live and must not. This
is not new; `dotfiles/designs/2026-08-01-state-locality-design.md` states it
and `portable.md` carries it. What is new is making it the axis the
directories are laid out on, so a reader knows from the path alone which kind
of file is in hand.

The alternative was a per-directory README each stating its own rules, which
is what `.handoffs/` does. That scales to one directory and stops: three copies
of that README already exist and already diverge.

### Keep `designs/` and `decisions/` both, with a plan-shaped boundary

Collapsing to `designs/` alone (the `dotfiles` shape) was considered and
rejected: a one-page measurement record and a forty-line design proposal are
different things to search for, and `workflow-skills` already has enough of
the first kind to justify a directory. Collapsing to `decisions/` alone was
rejected for the same reason in reverse.

The boundary chosen is whether acting on the file needs a plan. A design
proposes a shape and spawns work; a decision answers a question a reader can
apply as written. The test is about the reader's next move, which is easier to
apply than "is this an ADR" and does not depend on length.

What this does not do: it does not extract decisions out of designs. A design
that settles five questions stays one file; splitting it produces five records
that repeat the design and go stale independently.

### Date first, kebab-case, no type suffix

Prefix dates so the directory listing sorts by time and a stale file is
visible at a glance. Kebab-case because it is the majority form in every
record directory surveyed, and because `tasks/` cannot change: the task
tooling resolves slugs by filename stem with snake_case fixed in its schema,
so snake_case stays there as the one documented exception. No `-design` or
`-decision` suffix, since the directory already says so and three of nine
`dotfiles` designs already omit it.

### Front matter on every record

Records get a small Obsidian YAML block: `created`, `status`, and the
`supersedes`/`superseded_by`/`live` pointers. This is the one decision that
costs a migration, and the reason is that prose status lines cannot be
checked. A `created` that must match the filename date is a test; a bold
`Drafted:` line is not. The vocabulary is four states shared by designs and
decisions (`proposed`, `accepted`, `superseded`, `abandoned`) rather than two
vocabularies to keep straight.

Handoffs and task cards keep the schemas they have; both already work and both
have owners.

### Records are amended by callout or superseded by a new file, never rewritten

Both forms already exist in `dotfiles`; the rule picks when each applies. A
correction that leaves the conclusion standing is a dated callout in place. A
change of conclusion is a new dated record with the pointer fields set both
ways. The test is whether a reader who acted on the old file would now act
differently.

### `tasks/` ignore policy follows the handler

Under `repo-pr` the cards are the tracker, so they are committed. Under any
other handler the tracker owns the state and the scaffolding is local, which
is the `workflow-skills` `.gitignore` shape. `dotfiles` tracking its plans
under `gh-issue` is the inconsistency, and the fix is the ignore entry plus
the graduate-then-delete the plans already promise.

### One ignore channel for skill config: `.gitignore`

`.git/info/exclude` does not travel with a clone, so a fresh checkout has no
way to know a directory is local until the skill runs and writes the entry.
`.gitignore` is visible in the repo, so it also serves as documentation. The
`.coders.yml` tracked in `papercuts-plugin` is what the other channel
produces.

### The convention lives in this plugin

It is delivered like `writing_about_code.md`: a root content file, reached by
name from a `portable.md` Rules bullet, so it arrives in every harness and
every cloud session without any repo committing it. Each repo's
`dev_docs/README.md` and `.handoffs/README.md` shrink to pointers plus that
repo's exceptions, which ends the three-way copy of the handoffs README.

### Enforcement is a shared checker, later

`dotfiles/scripts/dev_docs_layout.test.sh` already checks the `tasks/`
contents and stray checkboxes. Two more checks fall out of this design: record
filenames match `YYYY-MM-DD-<slug>.md`, and a record's `created` matches its
date. A checker in this plugin that any repo's check suite can call is the
right home, and it is a follow-up rather than part of this change, so the
convention can land and be argued with before code depends on it.

## Migration

Each item is a follow-up in its repo. None is a prerequisite for merging this
design.

**`agent-guidance`** (this change): add `dev_docs_layout.md`, this record,
`dev_docs/README.md`, the `portable.md` bullet, and the `README.md` row. The
existing design record gains front matter.

**`dotfiles`:**

- Date `designs/claude-settings-portable-sync-design.md` (its body says
  2026-07-02) and add front matter to every design.
- Rename `papercuts_reports/` files to date-first.
- Move `2026-09-05-agents-md-rule-inventory.md` out of `designs/`; it is data,
  and `decisions/` is the nearer fit if it settles a question.
- Ignore `dev_docs/tasks/*` except `.task-config.yml` (the handler is
  `gh-issue`), and run the graduate-then-delete the three finished plans
  already schedule.
- Add `dev_docs/README.md`; shrink `.handoffs/README.md` to a pointer and its
  repo-specific notes; extend `dev_docs_layout.test.sh` with the two new
  checks, or replace it with the shared checker when that exists.
- Drop the stale `dev_docs/nightly_reports/` citation in `justfile`.

**`workflow-skills`:**

- Date and front-matter the undated files in `decisions/` and `designs/`;
  normalise slugs to kebab-case.
- Fold `workflow-review/` into `designs/` or a `<topic>.md`.
- Move `research/research-spike-lean-evaluation.md` to `decisions/` or
  `designs/` so `research/` is reserved.
- Delete `tasks/autopilot_hardening_plan/` (graduated) and finish
  `cao_usage_plan`'s graduation.
- Point `orchestrate-coders` at `.gitignore` instead of `.git/info/exclude`.
- Add `dev_docs/README.md`; shrink `.handoffs/README.md`.

**`papercuts-plugin`:**

- Untrack `dev_docs/orchestrate-coders/.coders.yml` and ignore the directory.
- Front-matter the one design; add `dev_docs/README.md`.
- Resolve the handoff whose milestones have closed.

## Not decided here

- Whether `dev_docs/tasks/` should ever hold non-card files inside a
  `<name>_plan/` (`DECISIONS.md`, `prompt.md`). The task tooling tolerates
  them; the plan-with-docs skill says to delete them. That is a
  `workflow-skills` question.
- The shape of the shared checker and where a repo calls it from.
- Whether `portable.md`'s handoffs bullet under "Output Formats" moves under
  "Rules" beside the new pointer. It works where it is.
