---
created: 2026-09-27
status: accepted
convention: ../../dev_docs_layout.md
---

# The layout checker finds a monorepo's package `dev_docs/` itself

## Context

`bestdan/finplan` is a monorepo whose root `dev_docs/` held about 60 files,
roughly half of them about one package only. Its pilot (bestdan/finplan#1255,
reported on #84) gave three packages their own `dev_docs/` and checked them by
calling `scripts/dev-docs-layout.py` once for the root and once per
`packages/*/dev_docs` from a wrapper of its own. That works unchanged, because
the checker lists files relative to the root it is given. It has two gaps. A
package's `dev_docs/` added later goes unchecked until someone edits the
wrapper. And a checker handed a package root takes it for the repository
root, so it has no way to reject `tasks/` or `.handoffs/` there, which the
convention keeps at the root because the tooling that owns each resolves one
location.

## Decision

Given a repository root, the checker finds every `dev_docs/` below it that git
sees, or that a walk finds outside a repository, and applies the same checks
to each. A package's `dev_docs/` holding `tasks/` or `.handoffs/` fails
instead of getting the `tasks/` content check. The first `dev_docs` in a path
decides its package, so a `dev_docs/` nested inside another one is the outer
tree's content. Consumers keep the single call they already make.

## Consequences

- Good, because a new package's `dev_docs/` is checked from its first commit,
  with no wrapper to edit.
- Good, because the root-only rule is enforced, not just documented.
- Bad, because discovery reads git's view, so a package `dev_docs/` whose every
  file is ignored is not found. The case is narrow: a `.gitignore` entry like
  `dev_docs/.handoffs/` is anchored at the root, so a package's `.handoffs/`
  is still visible.
- Bad, because a consumer that still calls the checker per package root checks
  each package twice. The output is correct, only duplicated, and the fix is
  to delete the extra calls.

## Revisit when

- A repository nests packages whose `dev_docs/` should be checked by a
  different version of the convention, which would need per-package opt-out.
- Walking a large non-git tree becomes a real cost; today the walk runs only
  outside a repository, which in practice means the test fixtures.

## Confirmation

The "monorepo package" section of `dev-docs-layout.test.sh` pins discovery, the root-only
rule, the nested case, and git-mode discovery with an ignored `tasks/`.

## Alternatives

- **Each repo lists its package roots:** no checker change, but nothing
  rejects `tasks/` in a package and a new package goes unchecked by default.
- **Discovery plus a single-root flag:** a second mode with no consumer asking
  for it.
