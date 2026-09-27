---
created: 2026-09-27
status: accepted
convention: ../../dev_docs_layout.md
---

# In a monorepo, a decision goes in the package whose code it constrains

## Context

Issue #84 proposed one placement test for everything under a package's
`dev_docs/`: a file goes in the package when every code path it describes is
inside that package. The finplan pilot (bestdan/finplan#1255) applied it and
found it held for live files but not for decisions. Most decisions mention
both the package they constrain and the boundary it meets, such as core and
the MCP server, so the test sent most of them to the root, where they sat
among repo-wide material again.

## Decision

Live files and decisions use different tests. A live `<topic>.md` goes in a
package only when every code path it describes is inside that package, and
otherwise at the root. A decision goes in the package whose code it
constrains, and any other package it names links to it.

## Consequences

- Good, because package decisions stay with the package's other docs, which
  is the point of giving the package a `dev_docs/`.
- Good, because a live file, which a contributor follows rather than
  consults, stays where every package that depends on it can find it.
- Bad, because a decision that constrains two packages equally has no
  mechanical answer. The author picks one and links from the other.

## Revisit when

- Decisions that constrain two packages equally turn out to be common, which
  would argue for sending those to the root.

## Confirmation

Nothing mechanical: the checker cannot tell which code a decision constrains.
Review holds it up.

## Alternatives

- **One test for both:** sends most decisions to the root, per the pilot.
- **Decisions always at the root:** the same result, without the pretence of a
  test.
