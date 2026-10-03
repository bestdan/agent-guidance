---
name: consult
description: Get a blind second opinion from a fresh agent at the same model tier or higher, returned with a calibrated confidence per decision. Use it BEFORE putting decisions to the user — before an AskUserQuestion, a "things that need your call" or "open questions" list, or any reply that ends by asking the user to choose — so that agreed, reversible calls get made and only the real ones reach the user. Also use when the user says "consult", "/consult", "second opinion" or "sanity check this", and on your own call when a second fix attempt has failed, when you are choosing between approaches just before something hard to undo, or when the user asks "are you sure?". Not for facts only the user knows, pure preferences, or lookups you can just do.
---

# consult

Asks the `agent-guidance:consultant` agent for an independent verdict on one
decision or a batch of them. The consultant starts with no context, reads the
repo itself, and returns for each decision a verdict, a confidence percentage,
and the crux the verdict turns on.

Its main use is as a filter in front of the user. Their attention is the
scarcest thing in a session: a call that you and a fresh agent agree on, and
that is cheap to undo, does not need it. The value comes from independence, and
most of what follows protects it.

## Which decisions to consult on

Take every decision you were about to put to the user, except the ones no agent
can answer: a fact about the user (a budget, a deadline, who owns something) or
a pure preference. Those go to the user directly, without a consult.

Outside that, consult on your own call when you have a concrete reason to doubt
it: a second fix attempt has failed, you are choosing between approaches just
before something hard to undo, or the user asked "are you sure?".

## 1. Write down your leaning, and keep it out of the brief

For each decision, record which option you would pick and how sure you are,
before the `Agent` call goes out — a line in your reasoning such as
`D2 leaning: B, ~65%`, or `D2 leaning: none`. Step 4 compares against it, and a
leaning reconstructed after reading the verdict is no longer independent of it.

Do not put any leaning in the brief, yours or the user's. A consultant that
sees a pick tends to anchor on it, and then its agreement tells you nothing.
The leaks are subtle: listing the favourite first, describing one option in
more detail, calling one "the current plan".

## 2. Write a self-contained brief

The consultant has seen none of this conversation. Give it:

- **The decisions**, numbered `D1`, `D2`, … even when there is only one, each
  with a clear answer shape. If you cannot state one as a decision, it is not
  ready to consult on.
- **The options** for each, stated neutrally and at comparable length. The
  consultant is told it may reject all of them.
- **Constraints** that rule things out: deadlines, compatibility, conventions
  the user has stated, what has already been tried and why it failed.
- **Where to look**: absolute file paths, commands, PR or commit references.
  Point at evidence rather than summarising it, so the consultant checks it.
- **What you have verified**, separately from what you believe.

A brief that worked, from a real consult:

```
D1: in /path/to/repo/skills.test.sh, should the PyYAML `yaml.safe_load`
second-opinion check on skill front matter be (A) kept as is, or (B) removed,
leaving only the hand-written plain-scalar validator? You may reject both.

A: keep both checks. The hand-written validator runs, and yaml.safe_load parses
the same front matter as an independent second opinion.
B: delete the PyYAML check. The hand-written validator is the only check.

Where to look: skills.test.sh and skills-selftest.test.sh, and any CI config
showing whether PyYAML is available where the tests run. `git log` for history.

Verified by me: nothing beyond the file names. Treat the rest as claims.
```

## 3. Pick the model: same tier or higher

Read your own model from your system prompt and pass the `model` override. The
tiers, lowest to highest: `haiku`, `sonnet`, `opus`, `fable`. Pass the next
tier up when there is one; at the top tier, pass your own. Never pass a lower
tier — a weaker consultant's agreement is not a second opinion.

```
Agent(
  subagent_type: "agent-guidance:consultant",
  model: "<same tier or higher>",
  description: "Consult on <decisions>",
  prompt: "<the brief>",
)
```

## 4. Act on each verdict

The consultant returns, per decision, **Verdict**, **Confidence**, **Basis**,
**Crux** and **Couldn't check**. Before trusting a number, read its Basis: a
high confidence resting on "from the brief" lines is your own claim reflected
back. When the crux is cheap to verify, verify it.

Then compare each verdict with your leaning. A `leaning: none` counts as
agreement when the consultant is at 70% or above, and as disagreement below.

| The decision was…  | Outcome                                | Do this                                                   |
| ------------------ | -------------------------------------- | --------------------------------------------------------- |
| headed to the user | agree, consultant ≥ 70%, cheap to undo | Decide it yourself; report it as decided (step 5).        |
| headed to the user | agree, but hard to undo                | Ask the user, showing both picks.                         |
| headed to the user | consultant < 70%, or disagree          | Ask the user, showing both picks and the crux.            |
| your own call      | agree                                  | Proceed.                                                  |
| your own call      | disagree, consultant ≥ 70%             | Stop and put it to the user with both picks and the crux. |
| your own call      | disagree, consultant < 70%             | Keep your call; say you overrode the consultant, and why. |

**Cheap to undo** means an edit or revert inside this session puts it back.
Anything pushed or published, data deleted, a message sent, an interface others
depend on, or money spent is hard to undo, however confident both of you are.

One consult per decision. Rewording the brief and asking again after a
disagreement is shopping for agreement, which defeats the point. Consult again
only when a materially new fact turns up, and report both answers.

## 5. Report it

The user should see what was decided for them as clearly as what they are
asked. In the reply:

- **Decided without asking:** each one in a line — the decision, the pick, the
  consultant's confidence, and its crux quoted rather than paraphrased. These
  come first, so the user can overturn one before it matters.
- **Needs your call:** each remaining question, carrying your pick, the
  consultant's pick and confidence, and the crux.

Agreement under 60% is weak agreement; say so rather than presenting it as
confirmation. Keep the consultant's full answer out of the reply unless the
user asks for it.
