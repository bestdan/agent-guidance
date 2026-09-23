---
created: 2026-09-23
status: accepted
convention: ../conventions.md
---

# A prose check rides the existing write hook rather than adding a handler

## Context

`hooks/comment-key-context.sh` was registered on the bare `Write|Edit` matcher
with no `if` gate, so `bash` already started on every write. A `case` prefilter
in the shell then exited before `python3` unless the payload carried a
tracker-key shape, which an ordinary markdown write does not. The insider-prose
pointer and detector need an interpreter on markdown writes, so what they cost
is an interpreter start, not a process.

Measured on one machine, 20 spawns each, per markdown write:

| Carrier                                         | ms    |
| ----------------------------------------------- | ----- |
| before, the prefilter rejects it                | 10.70 |
| widen the prefilter, one process does both jobs | 24.59 |
| a separate handler gated on `Write(**/*.md)`    | 38.89 |

The scan itself measured 0.44 ms. A separate handler is the expensive option,
not the clean one: it does not replace the existing hook, which still spawns on
every write underneath it.

## Decision

The hook is renamed `hooks/prose-context.*` and does both jobs in one process.
Its shell prefilter gains a second arm that admits a payload carrying a
markdown extension (`.md`, `.mdx`, `.markdown`, case-folded) at the end of a
JSON string. The arm matches the path, never the detector's shape.

## Consequences

- Good, because a markdown write pays one interpreter start, about 14 ms,
  instead of a second process at about 28 ms.
- Good, because the prefilter cannot silently miss a firing: it admits every
  markdown write, and the case-insensitive regex decides.
- Bad, because every markdown write now starts `python3`, including the many
  that produce no output after the session's first.
- Bad, because the arm over-admits any payload whose text contains `.md"`, such
  as a source file naming a README. Those take the comment-key path and cost
  the interpreter start for nothing.

## Revisit when

- The harness gains an `if` rule that can express "every source file" and
  "every markdown file" as separate handlers without the double spawn.
- A remeasurement puts the admitted path well above a bare interpreter start.
  The #78 measurement was 44.78 ms admitted against a 15.71 ms bare `python3`
  on a slower day, in line with the table above once scaled.

## Confirmation

`prose-context.test.sh` pins the prefilter's markdown arm with a payload that
carries no tracker-key shape and a sentence-start `The same 14 rows`, and pins
the case fold with an `.MD` path. Its section 10 pins the handler's absence of
an `if`.

## Alternatives

- **Gate the prefilter on the detector's shape:** rejected. A glob is
  case-sensitive where the regex is not, so `The same 14 rows` at a sentence
  start goes unmatched and the check does nothing, with nothing reporting it.
  A shell prefilter narrower than its check had already cost this repo a
  non-functional carrier twice.
- **A `Stop` hook reading the transcript:** rejected; it caps the cost at one
  process per turn but fires after the turn, too late for a `gh pr create` in
  that turn.
