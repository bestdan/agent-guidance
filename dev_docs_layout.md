# The `dev_docs/` layout

How a repo's `dev_docs/` directory is laid out: which directory holds what,
how files are named, what front matter they carry, and what never goes there.
One layout for every repo, so a session that learned it in one repo can use it
in the next without reading a README first.

This file is the live convention. The dated record of why it has this shape is
`dev_docs/designs/2026-09-13-dev-docs-layout.md` in `bestdan/agent-guidance`;
where the two disagree, this file is current.

## The one rule everything else follows from

**A date in the filename means the file is a record. No date means the file
is live.**

- A **record** describes a moment: a design as proposed, a decision as taken,
  a handoff as written, a report as measured. It is allowed to go stale
  forever, because the date in its name tells the reader when it was true. It
  is not rewritten; it is amended or superseded (see
  [Amending a record](#amending-a-record)).
- A **live** file describes the present and is kept current. When a live file
  and a record disagree, the live file wins and the record is history.

So directories split by which kind they hold. `designs/`, `decisions/`,
`.handoffs/`, and any reports directory hold records; the top level of
`dev_docs/` holds live files. `tasks/` holds neither: it is in-flight tracker
scaffolding owned by tooling, and it is deleted when the work lands.

This is the naming half of the state-locality rule in `portable.md`: don't
commit state another system owns, and if a file would become wrong when nobody
edits it, either name it for the moment it describes or keep it out of git.

## Directories

| Path                  | Holds                                                                | Kind      | Owner                                         |
| --------------------- | -------------------------------------------------------------------- | --------- | --------------------------------------------- |
| `dev_docs/README.md`  | the index: which of these directories this repo has, and why         | live      | the repo                                      |
| `dev_docs/<topic>.md` | durable knowledge: runbooks, subsystem descriptions, graduated plans | live      | the repo                                      |
| `dev_docs/designs/`   | the proposed shape of a system or a change to it                     | record    | the repo                                      |
| `dev_docs/decisions/` | one question, one answer, and the evidence at the time               | record    | the repo                                      |
| `dev_docs/tasks/`     | tracker config and `/plan-with-docs` scaffolding, nothing else       | transient | `workflow-skills`                             |
| `dev_docs/.handoffs/` | notes from one session to the next; gitignored                       | record    | the session                                   |
| `dev_docs/research/`  | research-spike trees, one per project; nothing else                  | live      | `workflow-skills` (`research-spike`)          |
| `dev_docs/<skill>/`   | one skill's machine-local config, gitignored                         | local     | the skill (`co-review`, `orchestrate-coders`) |
| `dev_docs/<kind>/`    | a class of dated reports the repo produces repeatedly                | record    | the repo                                      |

A repo has only the directories it uses. Every directory that exists is a row
in that repo's `dev_docs/README.md`. Nothing else goes under `dev_docs/`: a
file that fits no row is either a live `<topic>.md` or does not belong here.

### `dev_docs/<topic>.md`: live knowledge

Runbooks, how a subsystem works, the conventions a repo enforces, and the
durable part of a finished plan. Undated, kebab-case, kept current. Root-level
`AGENTS.md` links to these rather than repeating them.

When a live file grew out of a record, the two point at each other: the record
carries `live: <path>` in its front matter, and the live file's opening
paragraph names the record and says the live file wins.

### `dev_docs/designs/`: the shape of a change

A design says what is true today, what the change makes true, the alternatives
considered, and what it does not decide. It usually spawns a plan, and it is
the file a reviewer reads to judge whether the plan is the right one. Merging
the design is the decision to proceed.

A design is not a live description of the system. Once the change lands, the
durable part moves to a `dev_docs/<topic>.md`, and the design stays as the
record of what was intended.

### `dev_docs/decisions/`: one question, one answer

A decision record fits on a page: the question, the answer, the evidence
measured when it was taken, and what would reopen it. It needs no plan to act
on; a reader can apply it directly. Measurements and audits belong here when
they settle a question ("type-check with X because Y measured Z").

The boundary with `designs/`: if acting on the file needs a plan, it is a
design; if a reader can act on it as written, it is a decision. A design that
contains several decisions stays one design; do not split it into decision
records that repeat it.

### `dev_docs/tasks/`: tooling-owned scaffolding

`workflow-skills` owns this directory, and its skills define the contents:

- `.task-config.yml` (tracked) and `.task-config.local.yml` (ignored) name the
  repo's tracker handler.
- `<name>_plan/` directories are `/plan-with-docs` output: `<name>_plan.md`
  plus `<name>_task_N.md` cards, snake_case, in the task schema `skills/task`
  defines.
- `<slug>.md` flat cards are what the `repo-pr` handler files.

Nothing else. No designs, no notes, no reports; the layout test in a repo that
has one fails on anything else, and the state-locality rule says why: this
directory is scaffolding, not a tracker and not documentation.

**Ignore policy follows the handler.** Under `repo-pr` the cards are the
tracker, so they are tracked. Under any other handler (`gh-issue`, `linear`,
`jira`) the tracker owns the state, so `.gitignore` carries
`dev_docs/tasks/*` and `!dev_docs/tasks/.task-config.yml`, and plan
scaffolding stays local.

**Graduate, then delete.** A plan's last task moves its durable wisdom to a
`dev_docs/<topic>.md` and deletes the `<name>_plan/` directory. A plan whose
cards all read `done` and whose directory still exists is a bug in the plan,
not a record.

### `dev_docs/.handoffs/`: session to session

Gitignored and hidden, with one tracked `README.md`. The convention is short:

- Name: `YYYY-MM-DD-<short-topic>.md`.
- Front matter: `created`, `aim`, `branch`, `task`, `pr`, `expires`. `expires`
  is prose ("when #713 merges"), and any value containing `#` is quoted.
- Start with the aim, then only what the next session cannot reconstruct from
  the repo. Link to anything git, GitHub, or the tracker already knows.
- Every handoff ends by telling its reader to delete it when the work is done.

The directory is ignored twice on purpose: `.gitignore` keeps handoffs out of
commits, and `dprint.json` excludes `dev_docs/.handoffs/**` so an unformatted
handoff does not fail the format check. Keep both entries. The tracked
`README.md` explains why it is tracked and how to search a hidden directory;
it points here for the convention and adds only what is specific to its repo.

### `dev_docs/research/`: reserved

The `research-spike` skill owns this path and scaffolds
`dev_docs/research/<project>/`. A repo with no spike has no `research/`
directory. Prose research that is not a spike is a design or a decision, not a
file here: the skill's `validate` gate runs only once a project is
initialised, and a scan that finds nothing reports clean, so a stray file
there is never checked.

### `dev_docs/<skill>/`: machine-local config

A skill that needs per-machine config under `dev_docs/` gets one directory
named for the skill, holding one hidden file (`co-review/.co-review.yml`,
`orchestrate-coders/.coders.yml`). The directory is listed in `.gitignore`,
which is the one ignore channel for this class: it travels with the repo, so a
fresh clone knows the directory is local before anything writes to it. A probe
result or an auth choice that reaches a commit is the failure this prevents.

### `dev_docs/<kind>/`: repeated reports

A repo that produces the same kind of dated report more than once
(`papercuts_reports/`) gives it a directory. Files there follow the record
naming rule, `YYYY-MM-DD-<slug>.md`, date first: the date is the sort key and
the staleness signal, and a suffix date defeats both.

## Naming

- **Records:** `YYYY-MM-DD-<slug>.md`. The date is when the file was written,
  and it matches `created` in the front matter.
- **Live files:** `<slug>.md`, no date.
- **Slugs:** kebab-case, lowercase, ASCII. No type suffix: the directory says
  the file is a design, so `-design` on the name repeats it.
- **Exception:** `dev_docs/tasks/` uses snake_case (`<name>_plan/`,
  `<name>_task_N.md`) because the task tooling resolves slugs by filename stem
  and its schema fixes the form. Follow the tooling there.

## Front matter

Every record carries Obsidian YAML front matter. Quote any value that contains
`#`; an unquoted `#` after whitespace starts a YAML comment and the rest of the
value is silently lost.

Designs and decisions:

```yaml
---
created: 2026-09-13
status: accepted # proposed | accepted | superseded | abandoned
supersedes: 2026-08-01-old-name.md # when this replaces an earlier record
superseded_by: 2026-10-02-newer-name.md # set on the old record when replaced
live: ../conventions.md # designs only: the live file that grew from this
---
```

`status` is the one field that changes after the record is written. Merging
sets `accepted`; a later record sets `superseded` on this one and names itself
in `superseded_by`. Handoffs and task cards keep the schemas their owners
define (above, and `workflow-skills`' `skills/task`).

Live files carry no required front matter. A `title` or `tags` block for
Obsidian is fine.

## Amending a record

A record is not rewritten. Two changes are allowed:

- **A correction that keeps the conclusion:** a dated callout at the point of
  change, `> [!NOTE] Amended 2026-09-08: …`, so the reader sees the original
  and the correction together.
- **A change of conclusion:** a new dated record. The new one carries
  `supersedes:`, the old one gets `status: superseded` and `superseded_by:`,
  and nothing else in the old one changes.

Which one applies is decided by whether a reader who acted on the old file
would now do something different. If yes, supersede.

## `dev_docs/README.md`

Every repo with a `dev_docs/` has one. It is short: a table of the directories
this repo actually has, one line each on what this repo keeps in them, and any
exception this repo makes to this convention with the reason. It links here
for the convention itself rather than restating it.

## What never goes under `dev_docs/`

- **A tracker in any shape.** No `TODO.md`, no open-issue list, no checkbox
  backlog outside a `<name>_plan/`. A layout test may grep for `- [ ]` outside
  plan directories, and it should.
- **A copy of live state another system owns.** Link to the PR, the issue, the
  ledger entry.
- **Generated caches** of any of the above.
- **Plan residue.** See graduate-then-delete.

## Enforcement

Three tiers, weakest last:

1. **A layout test in the repo**, run by its check suite. Minimum checks:
   `dev_docs/tasks/` holds only what its section allows; no unchecked
   checkbox outside `dev_docs/tasks/*_plan/`; every file in a record directory
   is named `YYYY-MM-DD-<slug>.md` (or is `README.md`); a record's `created`
   matches its filename date. `bestdan/dotfiles`'
   `scripts/dev_docs_layout.test.sh` is the reference for the first two; the
   plugin will ship a shared checker for all four.
2. **This file**, reached by name from `portable.md`.
3. **Review.** A reviewer who sees a dated file edited in place, an undated
   record, or a design in `tasks/` says so.
