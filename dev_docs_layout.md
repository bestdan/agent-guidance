# The `dev_docs/` layout

How a repo's `dev_docs/` directory is laid out: which directory holds what,
how files are named, and what never goes there. One layout for every repo, so
a session that learned it in one repo can use it in the next.

This file is the umbrella. Each directory carries its own `README.md` with the
rules and template for that directory's files, because how to write a design
is not how to write a decision. The canonical copies of those READMEs are in
`bestdan/agent-guidance` under `dev_docs/`; a repo copies the ones it uses.

The decisions behind this layout are the `2026-09-13-*` records under
`dev_docs/decisions/` in `bestdan/agent-guidance`.

## The one rule everything else follows from

**A date in the filename means the file is a record. No date means the file
is live.**

- A **record** describes a moment: a decision as taken, research as gathered,
  a handoff as written, a report as measured. It is allowed to go stale
  forever, because the date in its name says when it was true. Its body is
  never rewritten; only the lifecycle fields and dated callouts its directory's
  README allows may change, and that README says how it is superseded or
  deleted.
- A **live** file describes the present and is kept current. When a live file
  and a record disagree, the live file wins.

This is the naming half of the state-locality rule in `portable.md`: don't
commit state another system owns, and if a file would become wrong when nobody
edits it, either name it for the moment it describes or keep it out of git.

## Three kinds of knowledge

- **Conventions** say what to do. They are live, and they are what an agent or
  contributor reads to work in the repo. A convention does not require reading
  the decisions behind it.
- **Decisions** say why, at the time, and what would change the answer. They
  are records: reference material for whoever revisits the choice, not
  guidance for whoever follows it.
- **Designs** propose a change. They are transient: a design exists to get
  agreement, and when the change lands it graduates into decisions and
  conventions and is deleted.

Research feeds designs and decisions with evidence, and handoffs carry a
session's state to the next one. Neither is guidance.

## Directories

| Path                  | Holds                                                      | Kind      | Rules in                                     |
| --------------------- | ---------------------------------------------------------- | --------- | -------------------------------------------- |
| `dev_docs/README.md`  | the index: which directories this repo has, and exceptions | live      | this file, below                             |
| `dev_docs/<topic>.md` | conventions and runbooks                                   | live      | this file, below                             |
| `dev_docs/designs/`   | proposals for changes not yet made                         | transient | `designs/README.md`                          |
| `dev_docs/decisions/` | why a choice was made and what would reopen it             | record    | `decisions/README.md`                        |
| `dev_docs/research/`  | evidence gathered to answer a question                     | record    | `research/README.md`                         |
| `dev_docs/.handoffs/` | notes from one session to the next; gitignored             | record    | `.handoffs/README.md`                        |
| `dev_docs/tasks/`     | tracker config and `/plan-with-docs` scaffolding           | transient | `workflow-skills` (`task`, `plan-with-docs`) |
| `dev_docs/<skill>/`   | one skill's machine-local config, gitignored               | local     | the skill                                    |
| `dev_docs/<kind>/`    | a class of dated reports the repo produces repeatedly      | record    | this file, below                             |

A repo has only the directories it uses. Every tracked directory that exists
is a row in that repo's `dev_docs/README.md`. Nothing else goes under
`dev_docs/`: a file that fits no row is either a convention or does not belong
here.

### `dev_docs/<topic>.md`: conventions and runbooks

How a subsystem works, what the repo enforces, how to run or release
something, and the durable part of a finished plan or design. Undated,
kebab-case, kept current. The repo's `AGENTS.md` links to these rather than
repeating them.

A convention may cite the decision records that support it, and usually does
not need to: the decisions are discoverable by date and topic when someone
revisits one. A reader following the convention never has to open them.

### `dev_docs/tasks/`: tooling-owned scaffolding

`workflow-skills` owns this directory and its skills define the contents:
`.task-config.yml` (tracked) and `.task-config.local.yml` (ignored) name the
tracker handler; `<name>_plan/` directories are `/plan-with-docs` output in
the task schema; `<slug>.md` flat cards are what the `repo-pr` handler files.
Nothing else: no designs, no notes.

Ignore policy follows the handler. Under `repo-pr` the cards are the tracker
and are tracked. Under any other handler the tracker owns the state, so
`.gitignore` carries `dev_docs/tasks/*` and `!dev_docs/tasks/.task-config.yml`
and plan scaffolding stays local. Either way a plan graduates and is deleted
when its work lands; a directory of `done` cards is residue.

### `dev_docs/<skill>/`: machine-local config

A skill that needs per-machine config under `dev_docs/` gets one directory
named for the skill, holding one hidden file (`co-review/.co-review.yml`).
The directory is listed in `.gitignore`, which is the one ignore channel for
this class: it travels with the repo, so a fresh clone knows the directory is
local before anything writes to it. An ignored directory needs no row in
`dev_docs/README.md`.

### `dev_docs/<kind>/`: repeated reports

A repo that produces the same kind of dated report more than once
(`papercuts_reports/`) gives it a directory. Files there are
`YYYY-MM-DD-<slug>.md`, date first, with front matter of `created` alone. A
report is a snapshot and is never amended; a later run is a new file.

## Naming

- **Records and designs:** `YYYY-MM-DD-<slug>.md`. The date is when the file
  was written and matches `created` in its front matter.
- **Live files:** `<slug>.md`, no date.
- **Slugs:** kebab-case, lowercase, ASCII. No type suffix: the directory says
  the file is a design, so `-design` on the name repeats it.
- **Exception:** `dev_docs/tasks/` uses snake_case (`<name>_plan/`,
  `<name>_task_N.md`) because the task tooling resolves slugs by filename stem
  and its schema fixes the form.

Every record and design carries Obsidian YAML front matter; each directory's
README says which fields. Quote any value containing `#`: an unquoted `#`
after whitespace starts a YAML comment and the rest of the value is lost.

## `dev_docs/README.md`

Every repo with a `dev_docs/` has one. It is short: a table of the tracked
directories this repo has, one line each on what this repo keeps there, and
any exception this repo makes to this convention with the reason. It names
this file, `dev_docs_layout.md` at the plugin root, rather than restating it.

## What never goes under `dev_docs/`

- **A tracker in any shape** other than the `repo-pr` handler's cards under
  `tasks/`. No `TODO.md`, no open-issue list, no checkbox backlog outside a
  `<name>_plan/`.
- **A copy of live state another system owns.** Link to the PR, the issue, the
  ledger entry.
- **Generated caches** of any of the above.
- **Residue:** a landed design, a finished plan.

## Enforcement

1. **The shared checker, `scripts/dev-docs-layout.py` at the plugin root**,
   run by each repo's check suite. It checks that `dev_docs/tasks/` holds only
   what its section allows; that no unchecked checkbox sits outside
   `dev_docs/tasks/*_plan/`; that every file in a record or design directory
   is `YYYY-MM-DD-<slug>.md` or `README.md`; that a record's `created` matches
   its filename date; and that a decision has a `## Revisit when` section.
   Subdirectories of `dev_docs/research/` are skipped, because the
   `research-spike` skill owns and validates those. Inside a repository it
   reads what git sees, so an ignored skill directory or plan never fails
   locally what CI would pass.

   A repo calls it as one entry in the suite it already has, a `*.test.sh` or
   a line in `check.sh`, and resolves the plugin root before the call:
   `AGENT_GUIDANCE_DIR` when set, else the repo's own resolver
   (`agents/agent-guidance-dir.sh` in `dotfiles`,
   `scripts/agent-guidance-dir.sh` in `workflow-skills`). A root that cannot be
   resolved, or an installed copy too old to ship the script, fails the entry
   rather than skipping it; a skipped check is green while checking nothing.
   CI that has no plugin install clones `bestdan/agent-guidance` and exports
   `AGENT_GUIDANCE_DIR`.

   ```sh
   root="${AGENT_GUIDANCE_DIR:-$(scripts/agent-guidance-dir.sh)}" || exit 1
   python3 "$root/scripts/dev-docs-layout.py" "$(git rev-parse --show-toplevel)"
   ```

   `dev-docs-layout.test.sh` in this repo pins each check at its boundary and
   runs the checker over this repo's own `dev_docs/`.
2. **This file**, reached by name from `portable.md`.
3. **Review.** A reviewer who sees a dated file rewritten, an undated record,
   or a design still present after its change landed says so.
