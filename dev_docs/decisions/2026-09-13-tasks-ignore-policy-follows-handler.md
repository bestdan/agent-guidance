---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# The `dev_docs/tasks/` ignore policy follows the tracker handler

## Context

`workflow-skills` ignores `dev_docs/tasks/*` except `.task-config.yml`.
`dotfiles` tracks its plan directories under a `gh-issue` handler.
`papercuts-plugin` tracks the config in an otherwise empty directory. Under
the `repo-pr` handler the task cards are the tracker; under any other
handler the tracker owns the state and the scaffolding is a local working
copy of it.

## Decision

Under `repo-pr`, cards are tracked. Under any other handler, `.gitignore`
carries `dev_docs/tasks/*` and `!dev_docs/tasks/.task-config.yml`, and plan
scaffolding stays local. Either way a plan graduates and is deleted when its
work lands.

## Consequences

- Good, because the committed state under `tasks/` is exactly the state the
  repo owns, which is the state-locality rule applied.
- Bad, because `dotfiles` has tracked plans to untrack and finished plans to
  delete.

## Revisit when

- A handler appears whose tracker cannot hold plan structure, so the local
  scaffolding becomes the only copy worth keeping.

## Confirmation

The `tasks/` contents check in `dotfiles/scripts/dev_docs_layout.test.sh`
covers what may be there, not whether it is ignored. Review for the ignore
entry.

## Alternatives

- **Always track:** commits a copy of tracker state that rots.
- **Never track:** breaks `repo-pr`, whose cards are the tracker.
