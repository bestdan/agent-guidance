---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# The hook matches `Write` and `Edit`, not `Read`

## Context

`Read` takes a file path too, so it could carry the same `if` condition. It
also fires far more often than the write tools, in browsing that has nothing to
do with producing a file.

The guidance exists for one moment: the point at which a session decides where
a record goes and what it is called.

## Decision

Register the hook on the `Write|Edit` matcher alone. A session reading under
`dev_docs/` gets nothing.

## Consequences

- Good, because the pointer lands in front of the act it is about, and not in
  front of ordinary browsing.
- Good, because the once-per-session marker is not spent on a read, which would
  leave the later write with no pointer.
- Bad, because a session that reads several records before writing one has
  already formed an idea of the layout from examples, and the pointer arrives
  after that.

## Revisit when

- Sessions are seen producing misfiled records after reading correctly filed
  ones, which would mean the examples mislead and the pointer is needed
  earlier.

## Confirmation

`dev-docs-context.test.sh` asserts the registration in `hooks/hooks.json`
covers both `Write` and `Edit`, which is the half that can be lost silently.
Nothing asserts `Read` is absent; adding it would be a deliberate edit.

## Alternatives

- **Add `Read`:** rejected; far more calls, none of them about to produce a
  file, and the first one would consume the session's single pointer.
