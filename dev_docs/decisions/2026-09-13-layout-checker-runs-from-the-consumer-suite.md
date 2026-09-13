---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# The layout checker ships in the plugin and runs from each repo's own check suite

## Context

`dev_docs_layout.md` names a layout test as its first enforcement tier. The
reference was `dotfiles/scripts/dev_docs_layout.test.sh`, which covered two
of the five checks, walked with `rg`, and lived in a private repo no other
consumer could call. The convention is delivered by the plugin, so the check
that enforces it has to reach the same repos the convention does. Each
consumer already has a check suite and a way to find the installed plugin:
`dotfiles` runs every `*.test.sh` from `scripts/run-tests.sh`,
`workflow-skills` runs a fixed list from `scripts/check.sh`, and both carry an
`agent-guidance-dir.sh` resolver.

## Decision

The checker is `scripts/dev-docs-layout.py`, a stdlib-only Python script at
the plugin root that takes a repo root and exits 1 on any violation. A
consumer runs it as one entry in the suite it already has, resolving the
plugin root first through `AGENT_GUIDANCE_DIR` or its own resolver. A root
that cannot be resolved, or an installed copy too old to ship the script,
fails that entry. The plugin does not install anything into a consumer and
does not ship a resolver of its own.

## Consequences

- Good, because one implementation checks every repo, and a new rule lands
  once and reaches all of them at the next plugin update.
- Good, because failing rather than skipping on a missing plugin keeps the
  entry honest; a check that skips is green while checking nothing.
- Bad, because a consumer's CI now needs the plugin present. The cost is a
  shallow clone of a public repo and one exported variable.
- Bad, because the checker reads what git sees, so an ignored file is never
  checked; that is the same answer CI would give, which is the point.

## Revisit when

- Plugins gain a way to deliver files or hooks into a consumer's tree, which
  would let the check run without the consumer wiring it.
- A consumer without a resolver appears and the `AGENT_GUIDANCE_DIR` route
  proves too fiddly, which would argue for a resolver in the plugin.
- The five checks stop being enough: designs still present after their change
  landed are the known gap, and a residue check needs a signal the layout does
  not carry today.

## Confirmation

`dev-docs-layout.test.sh` pins each check at its boundary and runs the
checker over this repo's own `dev_docs/`. Nothing checks that a consumer
wired it; that is each consumer's migration issue.

## Alternatives

- **Keep the `dotfiles` test as the reference:** private, two checks of five,
  and unreachable from any other repo.
- **A copy of the test in each repo:** the same drift the per-directory
  READMEs already pay for, on code rather than prose.
- **A shell script:** the fence-aware checkbox scan and the front-matter read
  are easier to get right in Python, and `prose-check.py` set the precedent.
