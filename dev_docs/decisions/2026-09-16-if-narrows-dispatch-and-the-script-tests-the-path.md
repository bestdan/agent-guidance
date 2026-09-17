---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# `if` narrows the dispatch, and the script's own path test backs it up

## Context

Registered on the bare `Write|Edit` matcher, the script spawns on every edit in
the repository and discards the payload after the fact. Measured against
2.1.274 with the script instrumented to log each spawn: three writes under
`src/` produced three spawns. With the handler's `if` field set, the same probe
produced none, and a write under `dev_docs/` still produced one.

An earlier revision of the design rejected `if`, because a condition expressed
there cannot be exercised by `dev-docs-context.test.sh`. That reason was too
strong: the condition cannot be unit-tested, but it can be measured in a live
session.

## Decision

Keep both layers. The handler's `if` field decides whether the process starts,
and the script's own path test decides whether it speaks. The script tests path
segments rather than a substring, and refuses a path whose last segment is
`dev_docs`.

## Consequences

- Good, because a session that never writes under `dev_docs/` pays no process
  spawns at all.
- Good, because the tested layer survives a config edit: if the `if` field is
  dropped or loosened, the script still says nothing outside `dev_docs/`.
- Bad, because the condition that does the narrowing is the one a suite cannot
  reach, so it rests on a live measurement and on the wiring assertions.
- Bad, because the rule has to carry a leading `**/`. `Write(dev_docs/**)`
  anchors at the project root: measured, it fires for `dev_docs/x.md` and not
  for `packages/x/dev_docs/x.md`, while `Write(**/dev_docs/**)` fires for both
  and still not for a write under `src/`. The script's own test never had that
  limit, so the anchor only started mattering once `if` gated the spawn.

## Revisit when

- The `if` field's semantics change, which would invalidate the spawn
  measurement rather than the script's test.
- A harness offers a matcher that takes a path, which would make one layer
  enough.

## Confirmation

`dev-docs-context.test.sh` pins the script's segment test at its boundaries,
including that `dev_docs_layout.md` at a repo root does not fire, and asserts
that `hooks/hooks.json` carries an `if` condition on each handler, with the
leading `**/` rather than just some condition. The spawn counts and the anchor
behaviour were measured live on 2.1.274.

## Alternatives

- **`if` alone:** rejected; the narrowing would rest entirely on a condition no
  test can exercise.
- **The path test alone:** what the earlier revision proposed; it is correct
  and costs a process spawn on every edit in the repository.
- **A substring test in the script:** rejected; it fires on
  `dev_docs_layout.md` at a repo root, which is this plugin every time someone
  edits the convention itself.
