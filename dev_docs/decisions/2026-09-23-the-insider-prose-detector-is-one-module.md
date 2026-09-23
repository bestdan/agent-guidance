---
created: 2026-09-23
status: accepted
convention: ../../writing_about_code.md
---

# The insider-prose detector is one module with three consumers

## Context

Three things run the dangling-reference signal: the `PreToolUse` hook over the
lines a write adds, `scripts/prose-check.py` over this repo's tracked markdown,
and the fixture suite. No `hooks/*.py` in this repo imported local code before
this, so the default was a copy of the pattern in each consumer.

The consumers differ in what they can strip before scanning. The hook holds
added lines, which carry no fence state: an added line inside a fenced block
looks like one outside it. `prose-check.py` streams whole files and can pair a
fence.

## Decision

`scripts/insider_prose.py` is a pure module, with no I/O and no side effects,
exporting `scan(text)`. It strips inline-code spans that pair within a line and
leaves an unmatched backtick's span alone. Each consumer strips what its own
input allows before calling it: `prose-check.py` drops fenced blocks, and the
hook drops single-line HTML comments. The hook reaches the
module by adding `GUIDANCE_ROOT/scripts` to `sys.path`, and refuses to import
at all when the root is unset, so a consumer repo's own `scripts/` is never
searched.

The module lives under `scripts/` rather than beside the hook because two of
its three consumers are scripts and the hook is the one that reaches across.

## Consequences

- Good, because the pattern exists once, so a change to it reaches the hook,
  the corpus check and the fixtures together.
- Good, because the fixtures test the module the hook actually runs.
- Bad, because the hook now depends on a file outside `hooks/`. A missing module
  is reported once per session, with the quoted rule, rather than failing the
  write.
- Bad, because the hook and `prose-check.py` can report differently on one
  sentence inside a fence. That follows from their inputs, not from the module.

## Revisit when

- The signal is dropped (see
  `2026-09-23-three-of-four-insider-prose-signals-were-dropped.md`). The module
  then goes with it, and the hook keeps the pointer alone.
- A second hook needs local code, which would make the `sys.path` arrangement
  a pattern worth a shared helper.

## Confirmation

`insider-prose.test.py` imports the module directly. `prose-context.test.sh`
pins that a hook whose root has no module reports it rather than going quiet.

## Alternatives

- **A copy of the pattern in each consumer:** rejected; three copies drift with
  nothing reporting it.
