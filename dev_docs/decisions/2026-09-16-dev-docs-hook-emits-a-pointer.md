---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# The `dev_docs/` hook emits a pointer, never the layout itself

## Context

`hooks/dev-docs-context.sh` returns `additionalContext` before a write under
`dev_docs/`. It could name `dev_docs_layout.md` or it could inline it. The file
is about 2,406 tokens, and the reason the layout was not already in the
always-on payload is that most sessions never need it.

A second copy would also drift. `scripts/dev-docs-layout.py` names
`dev_docs_layout.md` in its own failure output, so a session reading an inlined
paraphrase and a session reading the checker's error would be pointed at two
different texts.

## Decision

The hook names `dev_docs_layout.md`, the repo's `dev_docs/README.md`, the
README of the directory being written into, and the checker, and stops. The
model reads the files it needs.

## Consequences

- Good, because the eager cost the `portable.md` bullet existed to avoid is not
  reintroduced one write at a time.
- Good, because there is one copy of the layout, and the checker's failure
  output names the same file the hook does.
- Bad, because the guidance only lands if the model follows the pointer, which
  a payload would not depend on. The live probe showed it followed, and ongoing
  use is the only further evidence.

## Revisit when

- Sessions are observed taking the pointer and not reading the file, often
  enough that the layout has to be pushed rather than named.

## Confirmation

`dev-docs-context.test.sh` asserts the emitted context names
`dev_docs_layout.md` and pins the reading sequence, so a pointer that drops one
of the files fails. Nothing asserts the layout's body is absent; the script
holds one string and review is what keeps it a pointer.

## Alternatives

- **Inline the layout:** rejected; it puts about 2,406 tokens in front of every
  first write and creates a second copy to drift.
- **Inline a short paraphrase:** the same drift with less of the content, and
  nothing says which copy is right.
