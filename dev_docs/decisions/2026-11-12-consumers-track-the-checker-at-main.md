---
created: 2026-11-12
status: accepted
convention: ../../dev_docs_layout.md
---

# Consumers run the dev_docs layout checker from main, and this repo checks them before a merge

## Context

The repos that run `scripts/dev-docs-layout.py` have no plugin install in CI,
so each one carried its own step that cloned this repository's `main` and
exported `AGENT_GUIDANCE_DIR`. Every consumer is owned by the same person as
this repo, who wants a checker change to reach all of them at once.

Tracking `main` means a stricter checker can fail a consumer's CI on a commit
that changed nothing in that consumer. The checks #126 added would have done
that to `bestdan/workflow-skills` had its cleanup not merged first.

## Decision

Consumers reference the composite action `actions/dev-docs` at `@main`. It
exports `AGENT_GUIDANCE_DIR` as the copy the runner downloaded and, unless
told not to, runs the checker over the workspace. This repo's CI runs each
PR's checker over every public consumer's `main`, so a change that would turn
one red fails the PR rather than the consumer.

## Consequences

- Good, because a checker change reaches every consumer on merge, with no
  bump to review in each one.
- Good, because the wiring lives once, here, rather than as a copied clone
  step in each consumer.
- Good, because a breaking change is caught on the PR that makes it, where
  the fix is cheapest.
- Bad, because the consumer check sees only public repositories; the default
  token cannot clone a private one, which still learns of a break on its own
  next run.
- Bad, because the consumer check clones a repository this PR does not own,
  so a consumer's own unrelated violation on `main` fails this repo's CI until
  it is fixed there.
- Bad, because `@main` departs from pinning actions to a commit, which is the
  usual practice for a dependency nobody here controls.

## Revisit when

- A consumer is owned by someone else, or needs to choose when it takes a
  checker change; that consumer pins a commit.
- A private consumer breaks on a checker change often enough to justify a
  token that lets the consumer check clone it.

## Confirmation

The `dev-docs-action` job in `.github/workflows/tests.yml` runs the action
over this repo and over a tree with a violation, and the `consumers` job runs
the PR's checker over each public consumer's `main`.

## Alternatives

- **Pin a commit and let Dependabot bump it:** every checker change becomes a
  PR in each consumer, and consumers run an older checker until it merges,
  which is the opposite of what the owner wants.
- **Keep a clone step in each consumer:** the same behaviour as `@main`,
  copied into every repo.
- **A pre-commit hook:** pre-commit expects a fixed `rev:` and warns on a
  branch, so a local run would lag `main` until `pre-commit autoupdate`.
