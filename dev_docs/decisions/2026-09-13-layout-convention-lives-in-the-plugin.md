---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# The `dev_docs/` layout convention lives in this plugin

## Context

The convention has to reach every session in every repo, including cloud
sessions and harnesses without skills, without any consumer repo committing
it. The reviewing and authoring conventions already solved this shape: a
root content file, reached by name from a `portable.md` Rules bullet
(`2026-09-12-co-review-carrier-is-the-assembled-file.md` and its siblings).

## Decision

`dev_docs_layout.md` is a root content file of this plugin, named by a
`portable.md` Rules bullet, and read from the plugin root on any harness.
The per-directory READMEs are the one part that is copied into repos,
because they have to sit in the directory they govern.

## Consequences

- Good, because the convention arrives with the rest of the guidance and
  updates when the plugin does.
- Bad, because a session running a stale plugin copy reads a stale
  convention; the provenance block dates the payload so it can say so.

## Revisit when

- Plugins gain a way to deliver files into a repo's tree, which would let
  the READMEs be delivered rather than copied.

## Confirmation

The delivery tests prove `portable.md` reaches the session; nothing tests
that the bullet is followed. Review.

## Alternatives

- **Commit the convention into each repo:** four copies to keep in sync,
  and no route to a repo the author does not own.
