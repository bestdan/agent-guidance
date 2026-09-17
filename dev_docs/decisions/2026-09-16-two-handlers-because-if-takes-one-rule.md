---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# Two handlers on the matcher, because `if` takes one rule

## Context

The hook narrows at dispatch through the handler's `if` field, which needs to
cover both `Write` and `Edit`. The tidy spelling is one handler with
`Write(**/dev_docs/**)|Edit(**/dev_docs/**)`.

That alternation is accepted and matches nothing. Nothing is logged and there
is no parse error; the hook simply never fires. Measured against 2.1.274 with
the script instrumented to log each spawn: the alternation produced zero spawns
for a write directly under `dev_docs/`, where `Write(**/dev_docs/**)` alone
produced one.

## Decision

Register two handlers under the same `Write|Edit` matcher in
`hooks/hooks.json`, one carrying `Write(**/dev_docs/**)` and one carrying
`Edit(**/dev_docs/**)`, both running the same script.

## Consequences

- Good, because the hook fires for both tools, which the single-rule spelling
  silently did not.
- Bad, because the config now repeats the command and the glob, and reads as
  something a later editor would tidy back into one handler.

## Revisit when

- `if` starts accepting an alternation of tool rules, which would make one
  handler correct rather than silent.

## Confirmation

`dev-docs-context.test.sh` pins both handlers and fails an alternation, exactly
because collapsing them is the natural thing for a later editor to do.

## Alternatives

- **One handler with an alternation:** measured at zero spawns; it fails
  silently, which is worse than failing loudly.
- **Two separate matcher entries:** the same duplication one level up, with no
  advantage.
