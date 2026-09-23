---
created: 2026-09-23
status: accepted
convention: ../../writing_about_code.md
---

# Jev may measure the insider-prose rule, and no carrier may depend on it

## Context

Insider prose has two shapes. A dangling reference has one mechanical tier, a
regex. Historical narrative has none: "does this passage recount how the work
unfolded" is a judgment. Jev, TypeSafe's hosted model, answers exactly that
kind of question, a yes/no over text already in hand, with probabilities.

`workflow-skills` `dev_docs/typed-model-calls.md` admits a typed call for that
job, and it also bars a network call from any blocking gate and permits a key
requirement only as a fast path that degrades when the key is absent. The hook
runs for every installed user on every markdown write, offline or not, keyed
or not.

## Decision

No carrier in this plugin calls Jev. Historical narrative is carried by the
once-per-session quote of the rule, which the model reads and applies. Jev may
be used once, out of band and online, as a research instrument: run over the
insider-prose fixtures to measure whether a typed call beats the model
re-reading the rule after the pointer. That measurement has not been run.

## Consequences

- Good, because the hook stays offline and keyless in every repo it reaches.
- Good, because the comparison, when it runs, is against what is done today
  rather than against ground truth, which is the comparison that decides
  adoption.
- Bad, because historical narrative has no check beyond the model and a human
  reviewer reading the quoted rule.

## Revisit when

- The probe runs and a typed call beats the pointer across repeated passes. A
  margin measured once is not enough: `typed-model-calls.md` records one moving
  threefold across four runs of an identical prompt. Adoption would still need a
  path that degrades to the pointer when the call is unavailable.

## Confirmation

Nothing mechanical. No file in `hooks/` makes a network call, and review holds
it that way.

## Alternatives

- **Call Jev from the hook with a degrade path:** rejected; a network call on
  every markdown write, in repos this plugin does not own, for a judgment whose
  benefit over the pointer is unmeasured.
