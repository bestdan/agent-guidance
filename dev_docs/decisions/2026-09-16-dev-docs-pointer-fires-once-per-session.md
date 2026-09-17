---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# The `dev_docs/` pointer is emitted once per session, not once per write

## Context

A `PreToolUse` hook fires on every matching tool call. A plan that writes nine
records under `dev_docs/` would otherwise pay for nine copies of the same
paragraph, and repetition is the failure mode a conditional carrier exists to
avoid.

The hook payload carries a `session_id`, which is the key available at dispatch
time. The hooks reference documents a `scratchpad_dir` field on the
`PreToolUse` payload, but the live probe on 2.1.274 did not receive it.

## Decision

Write a zero-byte marker file keyed on `session_id` and emit the pointer only
when the marker is absent. The marker lands under `/tmp/claude`, the ordinary
fallback path, rather than the payload's `scratchpad_dir`. When the marker
directory cannot be written, emit the pointer anyway.

## Consequences

- Good, because a session writing many records pays for the pointer once.
- Good, because the failure mode of an unwritable marker directory is
  repetition rather than silence, which is the cheaper direction for guidance.
- Bad, because one zero-byte file per session accumulates under `/tmp/claude`
  and nothing prunes it.
- Bad, because a session that writes under `dev_docs/` early and again much
  later sees the pointer only the first time.

## Revisit when

- `scratchpad_dir` arrives on the `PreToolUse` payload, which would give the
  marker a directory the harness already cleans up.
- The accumulated markers are large enough to matter, which a zero-byte file
  per session makes unlikely.

## Confirmation

`dev-docs-context.test.sh` pins the suppression: a second call with the same
`session_id` emits nothing, and a call with a different one still gets its own
pointer. The unwritable-marker path is not tested; it rests on the `except
OSError` in the script.

## Alternatives

- **Emit on every write:** simplest, and pays the paragraph once per file in
  exactly the sessions that write the most.
- **Suppress on an unwritable marker directory:** would trade repetition for
  losing the guidance, which is the wrong way round.
