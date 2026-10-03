---
name: consult
description: Get a blind second opinion on one decision from a fresh agent at the same model tier or higher, returned with a calibrated confidence. Use when the user says "consult", "/consult", "get a second opinion", "sanity check this call", or "what would another agent say", and when you are about to make a consequential call you are not sure of — a design choice, a diagnosis, a risky change — and being wrong is expensive. Do not use for a lookup you can just do, or to delegate work.
---

# consult

Asks the `agent-guidance:consultant` agent for an independent verdict on one
decision. The consultant starts with no context, reads the repo itself, and
returns a verdict, a confidence percentage, and the crux the verdict turns on.

The value is independence. Everything below protects it.

## 1. Settle your own leaning first, and keep it to yourself

Before writing the brief, decide which option you would pick and how sure you
are, and write it down — a line in your reasoning such as "leaning: B, ~65%" —
before the `Agent` call goes out. Step 4 compares against it, and a leaning
reconstructed after reading the verdict is not independent of it. Do this even
when the user asked the question: if you genuinely have no view, record
"leaning: none" so step 4 reads the verdict as advice rather than a
cross-check. Do **not** put the leaning in the brief. A
consultant that sees your pick tends to anchor on it, and then its agreement
tells you nothing. Watch for leaks: listing your favourite first, describing
one option in more detail, or calling one "the current plan".

When the user invoked `/consult` with their own question, the leaning to
withhold is theirs as well as yours: brief the options, not the preference.

## 2. Write a self-contained brief

The consultant has seen none of this conversation. Give it:

- **The question**, as one decision with a clear answer shape.
- **The options**, each stated neutrally and at comparable length. Include
  "none of these" implicitly — the consultant is told it may reject them all.
- **Constraints** that rule things out: deadlines, compatibility, conventions
  the user has stated, what has already been tried and why it failed.
- **Where to look**: absolute file paths, commands, PR or commit references.
  Point at evidence rather than summarising it, so the consultant can check it.
- **What you have verified**, separately from what you believe. The consultant
  is told to treat the brief as claims, not facts.

If you cannot state the question as one decision, you are not ready to
consult. Split it, or ask the user.

## 3. Pick the model: same tier or higher

Read your own model from your system prompt and pass the `model` override on
the `Agent` call. The tiers, lowest to highest: `haiku`, `sonnet`, `opus`,
`fable`. Pass the next tier up when there is one; at the top tier, pass your
own. Never pass a lower tier — a weaker consultant's agreement is not a second
opinion.

```
Agent(
  subagent_type: "agent-guidance:consultant",
  model: "<same tier or higher>",
  description: "Consult on <decision>",
  prompt: "<the brief>",
)
```

## 4. Read the answer against your leaning

The consultant returns **Verdict**, **Confidence**, **Basis**, **Crux** and
**Couldn't check**. Compare its verdict with the leaning you set aside in step 1:

| Outcome                                | Do this                                                                         |
| -------------------------------------- | ------------------------------------------------------------------------------- |
| Agrees                                 | Proceed. Say you consulted and it agreed, with its confidence.                  |
| Disagrees, consultant confidence ≥ 70% | Stop. Bring both positions and the crux to the user; do not switch on your own. |
| Disagrees, consultant confidence < 70% | Keep your call, and say plainly that you overrode the consultant and why.       |
| "None of these"                        | Treat as a disagreement at its stated confidence.                               |

Check its **Basis** before trusting the number. A high confidence resting on
"from the brief" lines is your own claim reflected back — if the brief was
wrong, so is the verdict. When the crux is something you can verify cheaply,
verify it.

## 5. Report it

When the user asked for the consult, or when it changed what you do, tell them
in this order: the verdict, the confidence, the crux, and whether it matched
your own leaning. Quote the consultant's **Crux** rather than paraphrasing it.
Keep the full answer out of the reply unless they ask for it.
