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
| `<record>/references/` | a record's own artifacts: probe scripts, captures, results | record    | this file, below                             |

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

### `YYYY-MM-DD-<slug>/`: a record with artifacts

A research or design session often produces something that is not prose: the
script that measured the thing, the capture it read, the table it produced.
That is evidence, and it belongs to the record that cites it — not in the
repo's `scripts/` or `src/`, where a reader has to guess that it is nobody's
runtime code and a maintainer has to keep it working forever.

**A record that has artifacts is a directory instead of a file, named the same
way minus the `.md`.** It holds exactly two things:

```text
dev_docs/research/
  2026-09-13-dev-docs-survey.md   # no artifacts: still a file
  2026-09-19-io-latency/          # has artifacts: a directory
    README.md                     # the record, front matter and all
    references/
      probe-fsync.py
      raw/2026-09-19-run-1.csv
  uid-migration/                  # a research spike (undated); different rules
```

- **`README.md` is the record.** Same front matter, same rules, same directory
  README as the flat form; `created` matches the date on the directory. The
  file is a `README.md` so the tree renders the record when someone opens the
  directory, rather than making them pick a file. The fields are unchanged,
  but a relative path inside one resolves from a file one level deeper, so
  every `../` in a template gains a second: `../conventions.md` becomes
  `../../conventions.md`, and a sibling record becomes `../<its name>.md`.
- **`references/` holds everything else**, at any depth and in any shape the
  evidence came in. Nothing under it is checked: not the names, not the
  suffixes, not a checkbox in a captured note. A frozen artifact is not a
  backlog and not a record, so the naming rules do not reach it.

Nothing else sits in the bundle. A second directory beside `references/`, or a
loose script next to the `README.md`, fails the checker — one place to look,
always the same one. The flat file the directory replaced goes; leaving both is
one date and slug naming two records, and the checker says so. The converse is
not checked: an empty `references/` is invisible to git, so a bundle with no
artifacts left passes and it is review that asks why it is not a file again.

This applies to `research/`, `designs/` and `decisions/` alike. A design's
bundle is transient like the design: the prototype is deleted with it when the
change lands, and anything worth keeping has become real code by then.

**What does not belong in `references/`:** anything another thing imports,
CI runs, or a person is expected to keep working. Those are code, and code
lives where the repo keeps code. Nothing in a bundle is meant to be imported,
and the bundle's name half-enforces that: a directory beginning with a digit
and containing hyphens is not a Python identifier, so no dotted import can
name it. JavaScript resolves a path rather than an identifier and reaches it
fine, and Python still reaches it through `sys.path` or
`importlib.util.spec_from_file_location` — so for everything but the dotted
import this is convention, not mechanism. Run these by path, the way a reader
reproducing the record would. Keep each script standalone, with its invocation
and its dependencies in a comment at the top, because the record is the only
documentation it will ever get.

**Inside a research spike**, the same `references/` name works at the project
or track level, and the `research-spike` skill's validator ignores it. It must
not go inside `obligations/` or `contracts/`, which reject every non-`.md`
file by design.

### `dev_docs/<kind>/`: repeated reports

A repo that produces the same kind of dated report more than once
(`papercuts_reports/`) gives it a directory. Files there are
`YYYY-MM-DD-<slug>.md`, date first, with front matter of `created` alone. A
report is a snapshot and is never amended; a later run is a new file.

## Naming

- **Records and designs:** `YYYY-MM-DD-<slug>.md`. The date is when the file
  was written and matches `created` in its front matter. One that carries
  artifacts is `YYYY-MM-DD-<slug>/` instead, holding `README.md` and
  `references/`.
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
   `dev_docs/tasks/*_plan/`; that every entry in a record or design directory
   is `YYYY-MM-DD-<slug>.md`, a `YYYY-MM-DD-<slug>/` bundle, or `README.md`;
   that a bundle holds a `README.md` record and nothing outside `references/`,
   with no flat `YYYY-MM-DD-<slug>.md` beside a bundle of the same name;
   that a record's `created` matches its date; and that a decision has a
   `## Revisit when` section. Undated subdirectories of `dev_docs/research/`
   are skipped, because the `research-spike` skill owns and validates those —
   the date is what tells a bundle from a spike. Nothing under a `references/`
   tree is checked. Inside a repository it
   reads what git sees, so an ignored skill directory or plan never fails
   locally what CI would pass. The `dev_docs/tasks/` check is the exception
   and always reads the filesystem: an ignored plan directory is legitimate
   content there, and a stray file is stray whether or not anyone committed
   it.

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
