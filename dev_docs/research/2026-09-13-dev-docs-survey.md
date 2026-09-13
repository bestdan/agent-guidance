---
created: 2026-09-13
question: "How is dev_docs/ actually laid out across the four repos that use it, and where do they disagree?"
feeds: ../designs/2026-09-13-dev-docs-layout.md
---

# Survey of `dev_docs/` across four repos

## Question

How is `dev_docs/` actually laid out across the four repos that use it, and
where do they disagree?

## Method

Read on 2026-09-13 with `eza -Ta`, `rg`, and file reads, over local checkouts
of `bestdan/agent-guidance`, `bestdan/dotfiles`, `bestdan/workflow-skills`,
and `bestdan/papercuts-plugin`, including each repo's `.gitignore`,
`dprint.json`, `AGENTS.md`, and the `workflow-skills` skills that prescribe a
`dev_docs/` layout (`plan-with-docs`, `task`, `research-spike`, `auto-pilot`,
`co-review`, `orchestrate-coders`). Three of the four repos were surveyed by
subagents; their reports were read in full and the claims below were not
re-verified individually except where marked.

## Findings

### The only consistent directory is `.handoffs/`

All three repos that have it share a `README.md` copied from `dotfiles`, with
the same naming rule (`YYYY-MM-DD-<short-topic>.md`), the same front matter
(`created`, `aim`, `branch`, `task`, `pr`, `expires`), and the same
ignored-twice mechanism (`.gitignore` plus a `dprint.json` exclude). That
README is the only written convention in any of the four repos, and it
covers one directory. The `agent-guidance` copy already carries a
"Divergence from the `dotfiles` original" section.

### `designs/` and `decisions/` have no stated boundary

- `dotfiles` has `designs/` only, nine files. Several are standing decisions
  by their own status line ("accepted on merge — merging this document is the
  decision"). `2026-09-05-agents-md-rule-inventory.md` is machine-readable
  data with a YAML head, not a design.
- `workflow-skills` has both. `decisions/` (eight files) holds measurement
  records such as `python_type_checking.md` ("Measured 2026-09-04");
  `designs/` (five files) holds proposals. `workflow-review/` sits beside them
  holding two more documents that read as designs.
- `papercuts-plugin` has `designs/` only, one file, which says "merging this
  document is the decision".

### Dating is applied to about half the records

`dotfiles/designs/` is dated except `claude-settings-portable-sync-design.md`,
whose body carries `_2026-07-02_`. `workflow-skills/decisions/` is 3 of 8
dated, `designs/` 1 of 5. `dotfiles/papercuts_reports/` dates as a suffix
(`papercuts_triage_2026-07-20.md`); every other directory uses a prefix.
`portable.md` already says "a file that records a moment must carry its date
in the filename or path".

### Slug case is unsettled inside single directories

`workflow-skills/decisions/` mixes `linear_read_fastpaths.md` with
`2026-09-05-cloud-session-plugin-and-proxy.md`; its `designs/` mixes
`research_spike_skill.md` with `auth-key-resolution.md`. `dotfiles/designs/`
uses a `-design` suffix on three of nine files.

### Only `tasks/` and `.handoffs/` use front matter

Designs and decisions carry status as prose: `**Status:** proposed`,
`Date: 2026-08-01`, `Supersedes: …`. Amendment is done two ways in
`dotfiles`: `designs/2026-09-04-agents-md-context-budget.md` is amended in
place with a `> [!NOTE] Amended 2026-09-08` callout;
`tasks/papercuts_oss_plan/papercuts_oss_task_11_assessment.md` supersedes an
earlier draft by saying so in prose.

### `tasks/` tooling is consistent; the repos are not

- Ignore policy differs. `workflow-skills` ignores `dev_docs/tasks/*` except
  `.task-config.yml`. `dotfiles` tracks its plan directories under a
  `gh-issue` handler. `papercuts-plugin` tracks `.task-config.yml` in an
  otherwise empty directory.
- Graduate-then-delete is written in `skills/plan-with-docs` ("A plan isn't
  done until its scaffolding is gone") and honoured nowhere.
  `workflow-skills/tasks/autopilot_hardening_plan/` holds 26 cards marked
  `done` beside the graduated `dev_docs/auto-pilot-hardening.md`. `dotfiles`
  has three plans whose final card is "delete this directory", all present.
- `dotfiles/tasks/cmux_session_checkpoint_plan/` holds only a `design.md`;
  `papercut-dotfiles-dir_plan/` holds only a dated checkbox plan with no
  front matter. Both pass `scripts/dev_docs_layout.test.sh`, which checks the
  directory name and nothing inside it.
- `workflow-skills`' task cards omit `expires`, which its own schema requires;
  `validate.py` downgrades that to a warning.

### Skill config under `dev_docs/` uses three ignore channels

`co-review` appends `dev_docs/co-review/` to `.gitignore`;
`orchestrate-coders` writes to `.git/info/exclude`; `/task-config` uses a
local exclude for tracker handlers. Result:
`papercuts-plugin/dev_docs/orchestrate-coders/.coders.yml` is tracked, and it
is a machine-local probe result (`installed: false` for two backends, an auth
choice) that is wrong on every other machine.

### `research/` is misused once

`workflow-skills/dev_docs/research/research-spike-lean-evaluation.md` is a
flat document, not the `<project>/` tree the `research-spike` skill
scaffolds. `scripts/check.sh` lines 14-17 say the repo does not gate on that
tree (verified by reading the file), and the skill's own documentation notes
that "no research dir" and "wrong tree scanned" produce identical output.

### No repo has a `dev_docs/README.md`

`papercuts-plugin` has no `AGENTS.md` either, and its root `README.md` does
not mention `dev_docs`. `workflow-skills`' `AGENTS.md` carries a routing
table to individual files; `dotfiles`' carries pointers. Neither describes
the directories.

### Layout enforcement exists in one repo

`dotfiles/scripts/dev_docs_layout.test.sh` checks that `dev_docs/tasks/`
contains only `*_plan/` directories and `.task-config*.yml` files, and that
no unchecked `- [ ]` appears under `dev_docs/` outside a plan directory. It
skips `.handoffs/` because `rg` skips hidden paths. Its comment header cites
the state-locality design as the source of both rules.

### Stale references

`dotfiles/justfile:48` cites `dev_docs/nightly_reports/`, which no longer
exists. `dotfiles/designs/2026-08-01-state-locality-design.md` §5 says its
tier-2 rule landed in `agents/AGENTS.md`; the rule is now in
`agent-guidance/portable.md`.

## Feeds

`../designs/2026-09-13-dev-docs-layout.md`.
