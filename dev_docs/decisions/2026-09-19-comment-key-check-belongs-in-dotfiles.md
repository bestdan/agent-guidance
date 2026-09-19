---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# The ticket-key comment check is built in `bestdan/dotfiles`

## Context

`portable.md` now says a code comment carries no ticket key unless it is a
`TODO`. That trigger is mechanically detectable — an added comment line matching
`[A-Z][A-Z0-9]*-\d+` that is not on a `TODO` line — so `portable.md`'s own rule
about a machine-decidable rule belonging in a check applies to it.

The check has to be diff-scoped. A key in a comment that pre-dates the rule is
not a finding, and a whole-tree pass cannot tell an added line from an old one.
That rules out the shape both of this repo's existing checks use:
`scripts/prose-check.py` and `scripts/dev-docs-layout.py` read a finished tree
from a consumer repo's check suite.

This plugin does register `PreToolUse`. `hooks/hooks.json` has declared a
`Write|Edit` matcher with two `dev_docs` handlers since #41 and #42, so a guard
here would not be a new hook event — an earlier draft of this record claimed it
would be, and that claim was false.

Two narrower facts decide it instead. The plugin's Codex hook path is declared
but unverified (#39), so a guard registered for Codex may silently never fire.
And the `dev_docs` handler is cheap because most sessions never write under
`dev_docs/`; a matcher on source-file writes has the opposite profile, firing on
nearly every write in every session.

`bestdan/dotfiles` already runs guards of this shape on the two machines that do
most of the writing. `agents/guard_pr_body.py` and `agents/guard_noop_git_add.py`
are both `PreToolUse` hooks, with the registration, test harness and debugging
path in place.

## Decision

The check is built in `bestdan/dotfiles`, beside `guard_pr_body.py`, and is
filed there as issue #857. This repo carries the rule as prose, and the prose
keeps its full rationale rather than shrinking to a pointer at a guard most of
its readers do not have.

## Consequences

- Good, because the check lands where the hook machinery exists and where the
  per-write cost is paid by the two machines that benefit.
- Good, because the rule still reaches every reader by prose, on whichever
  carrier delivers `portable.md` to them.
- Bad, because the rule and its enforcement live in different repositories and
  can drift. A reword here does not reach the check, and nothing reports the gap.
- Bad, because the cloud and Codex readers get prose alone, so the rule is
  enforced on two machines and trusted everywhere else.

## Revisit when

- The Codex hook path is verified on a live session (#39), which removes the
  reason a guard here would be unreliable for one of the three audiences.
- The prose alone is measured as insufficient: keys keep reaching `main` from
  sessions on the two machines the dotfiles guard covers.

## Confirmation

Nothing in this repo. The check is bestdan/dotfiles#857; until it lands the rule
rests on the prose and on review.

## Alternatives

- **A `PreToolUse` guard in this plugin:** rejected on the two grounds above —
  the unverified Codex path, and a matcher that would fire on nearly every write
  rather than on the rare trigger the `dev_docs` handler was built for.
- **A tree-scoped check beside `prose-check.py`:** rejected; it cannot tell an
  added line from one that pre-dates the rule.
