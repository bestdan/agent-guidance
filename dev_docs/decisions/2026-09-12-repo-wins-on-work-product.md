---
created: 2026-09-12
status: accepted
convention: ../conventions.md
---

# The repo wins on work-product conventions; session rules hold regardless

## Context

The guidance this plugin carries is one developer's defaults, and it travels
into repos that developer does not own. A repo's own `AGENTS.md`,
`CONTRIBUTING.md`, or PR template can disagree with it. Before this decision
nothing said what happens then, and the default leans the wrong way: a
user-level file arrives flagged as overriding default behaviour, a repo file
arrives as ordinary context. Some of the carried rules are preferences
(commit format, review style); others are safety machinery (worktree
isolation, the Bash sandbox).

## Decision

`## Precedence` in `portable.md` splits a conflict in two. Conventions about
the work product, such as commit format, PR title and body shape, review
style, code style, and test layout, go to the repo's documented convention.
Rules about the session's own environment and workflow, such as worktree
isolation, the sandbox, which CLI tools to use, and a local task runner, hold
regardless of what the repo says.

## Consequences

- Good, because the rule is safe to carry into a repo the author does not
  own: a repo that states its own conventions gets them.
- Good, because "the repo wins" cannot be used to switch off the sandbox or
  worktree rules, which a repo has no standing over. A repo that appears to
  is describing its own CI.
- Bad, because nothing enforces it. Both instruction sets land in the same
  context window and the model arbitrates. The section is a stated tiebreak.

## Revisit when

- A harness gains a mechanism for ranking instruction sources, so the
  tiebreak can be enforced rather than stated.
- A repo override is observed defeating a safety rule in practice, which
  would mean the split is not being read as intended.

## Confirmation

Nothing. The section is text in `portable.md`, and the delivery tests prove
only that the file reaches the session.

## Alternatives

- **User guidance always wins:** imposes one developer's PR and review style
  on repos that have their own.
- **Repo always wins:** lets any `AGENTS.md` override the sandbox and
  worktree rules.
