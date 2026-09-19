---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# The ticket-key comment check is built in `bestdan/dotfiles`, not here

## Context

`portable.md` now says a source comment carries no ticket key unless it is a
`TODO`. That trigger is mechanically detectable: an added comment line matching
`[A-Z][A-Z0-9]*-\d+` that is not on a `TODO` line. The rule in `portable.md`
about a machine-decidable rule belonging in a check therefore applies to it.

This repo ships two kinds of check already. `scripts/prose-check.py` and
`scripts/dev-docs-layout.py` both read a finished tree from a consumer repo's
check suite. Neither sees a tool call, and this plugin declares only
`SessionStart` in `hooks/hooks.json`.

The check this rule wants is diff-scoped. It has to see added lines, which
means a `PreToolUse` guard on the write, or a commit-time or CI-time pass over
a diff. `bestdan/dotfiles` already runs guards of exactly that shape:
`agents/guard_pr_body.py` and `agents/guard_noop_git_add.py` are both
`PreToolUse` hooks, and the machinery for registering, testing and debugging
one is in place there.

The counter-argument is the one issue #39 makes about the backtick guard: this
plugin's readers are a strictly larger set than that repo's two machines, so a
guard there leaves cloud containers and Codex sessions uncovered. It holds for
the comment check too.

## Decision

The check is built in `bestdan/dotfiles`, beside `guard_pr_body.py`. This repo
carries the rule as prose only, and the prose keeps its full rationale rather
than shrinking to a pointer at a guard most of its readers do not have.

## Consequences

- Good, because the check lands where the hook machinery and its test harness
  already exist, rather than opening a second hook event in a plugin that has
  never used one.
- Good, because the rule still reaches every reader by prose, on whichever
  carrier delivers `portable.md` to them.
- Bad, because the rule and its enforcement live in different repositories and
  can drift. A reword here does not reach the check, and nothing reports the
  gap.
- Bad, because the cloud and Codex readers get prose alone, so the rule is
  enforced on two machines and trusted everywhere else.

## Revisit when

- This plugin grows a `PreToolUse` hook for another reason, and the Codex hook
  path is verified on a live session. Both are open in issue #39; either one
  landing makes a guard here cheap enough to move.
- The prose alone is measured as insufficient: keys keep reaching `main` from
  sessions on the two machines the dotfiles guard covers.

## Confirmation

Nothing in this repo. The check is an issue filed against `bestdan/dotfiles`,
and until it lands the rule rests on the prose and on review.

## Alternatives

- **A `PreToolUse` guard in this plugin:** rejected for now; it is a new hook
  event here, and issue #39 records that the Codex hook path is declared but
  unverified, so a guard registered for Codex may never fire.
- **A tree-scoped check beside `prose-check.py`:** rejected; a key in a comment
  that pre-dates the rule is not a finding, and a whole-tree pass cannot tell
  an added line from an old one.
