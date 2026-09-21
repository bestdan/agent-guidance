---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# Enforcement of a convention lives in the repo that owns the convention

> [!NOTE] 2026-09-20: the check landed. `hooks/comment-key-context.sh` is the
> handler this record anticipated, pinned by `comment-key-context.test.sh`; the
> Confirmation section below is the state before it did.

## Context

`portable.md` says a code comment carries no ticket key unless it is a `TODO`.
The trigger is mechanically detectable — an added comment line matching
`[A-Z][A-Z0-9]*-\d+` outside a `TODO` — so `portable.md`'s own rule about a
machine-decidable rule belonging in a check applies to it, and the only open
question is which repo builds it.

`bestdan/dotfiles` is the tempting answer, because the working `PreToolUse`
guards are there: `agents/guard_pr_body.py` and `agents/guard_noop_git_add.py`,
with the registration and test harness around them.

It is the wrong answer, and this repo had already reached that conclusion twice
without generalising it. Issue #38 states it for the rule-reachability checker:
"this repo owns the conventions, and a repo that inherits a rule set has no
standing to validate it." Issue #39 states it for the backtick guard, from the
audience side: a guard in `bestdan/dotfiles` reaches the two machines that repo
is installed on, while `portable.md`'s readers include cloud containers, Codex
sessions, and any machine carrying the plugin without that repo.

The machinery argument does not hold either. `hooks/hooks.json` has declared a
`PreToolUse` block on `Write|Edit` since #41 and #42, with
`hooks/dev-docs-context.sh` and `dev-docs-context.test.sh` as the worked
example.

A check in this repo's own suite is a separate wrong answer.
`scripts/prose-check.py` and `scripts/dev-docs-layout.py` read a finished tree,
and a repo's suite only ever sees that repo. This rule has to catch a comment
as it is written, in whatever repo a session is working in, which the plugin
hook reaches and a suite does not.

## Decision

Enforcement of a convention is built in the repo that owns the convention. For
the conventions in this plugin, that is here: a `PreToolUse` handler on the
existing `Write|Edit` matcher, following `dev_docs/`'s handler in advising
rather than denying. The ticket-key check is issue #50.

## Consequences

- Good, because a rule and the check that holds it up are read, reworded and
  reviewed together, so neither drifts without the other in the diff.
- Good, because the check reaches every session the convention reaches, rather
  than the two machines that install one particular dotfiles repo.
- Good, because it states as a rule what #38 and #39 each argued separately, so
  the next check does not re-derive it.
- Bad, because the Codex hook path here is declared but unverified (#39), so a
  guard may not fire for a Codex session even though the convention reaches it
  by concatenation.
- Bad, because every check added here runs in consumer repos that never asked
  for it, so a bug in one is felt outside this repo. The advise-never-deny shape
  bounds that cost to a missing pointer.

## Revisit when

- A convention's enforcement genuinely needs machine-local state — a path, a
  credential, a tool only some machines have — which is the one case this rule
  cannot serve and `bestdan/dotfiles` can.
- The plugin hook path stops reaching a consumer repo, which would leave the
  suite or the machine-local repo as the only carriers.

## Confirmation

Nothing yet. Issue #50 carries the check and asks for a test suite in the shape
of `dev-docs-context.test.sh`; until that lands the rule rests on prose and on
review.

## Alternatives

- **A guard in `bestdan/dotfiles`:** filed as #857 and withdrawn. It reaches two
  machines, and it would let a rule's prose shrink toward an invariant its
  readers cannot rely on — #39's argument, which applies to any check placed
  away from its convention.
- **A tree-scoped check beside `prose-check.py`:** rejected; it cannot tell an
  added line from one that pre-dates the rule, and a repo's suite never sees the
  repos where the comments are written.
