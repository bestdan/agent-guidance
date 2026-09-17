---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# The `dev_docs/` hook never denies a write, and exits 0 on every path

## Context

A `PreToolUse` hook can block the tool call, either by returning
`permissionDecision: deny` or simply by exiting nonzero. Blocking is available
here and would make the layout mandatory rather than advisory.

The layout already has an enforcement tier. `scripts/dev-docs-layout.py` runs
over a finished tree from a repo's check suite, where saying no costs a failed
check rather than a lost edit.

## Decision

The hook returns `additionalContext` and nothing else. It never sets a
permission decision, and it exits 0 on every path, including a payload it
cannot parse and a path it decides not to speak about.

## Consequences

- Good, because the write that fixes a layout violation is not itself blocked,
  which a denying hook could not distinguish from the violation.
- Good, because a bug in the script costs a missing pointer rather than a
  session that cannot write files. A nonzero exit would block the tool call.
- Bad, because a session that ignores the pointer writes a misfiled record, and
  nothing stops it until the checker runs.

## Revisit when

- Misfiled records reach `main` often enough that the checker at CI time is too
  late, and the cost of blocking a fixing write is worth paying.

## Confirmation

`dev-docs-context.test.sh` asserts exit 0 on a malformed payload, and pins the
emitted JSON to `hookEventName` plus `additionalContext`. Nothing asserts the
absence of a permission decision; that rests on review.

## Alternatives

- **`permissionDecision: deny` on a misfiled path:** rejected; guidance is not
  a safety rule, and it would block the corrective write too.
- **Exit nonzero on a parse failure:** rejected; that turns a script bug into a
  blocked tool call.
