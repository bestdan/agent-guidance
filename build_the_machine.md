# Use the model to build the machine, not to be the machine

Spend tokens freely to _make_ things: exploring a problem, drafting, writing
scripts, tests, and tools. Before putting a model on the _runtime path_ of
anything that recurs — a model call that happens every time the process runs,
rather than once while you build it — run it through the tests below. When an
agent does the same shape of task a third time, often enough to be worth
scripting, and the steps have stopped changing, turn that task into
deterministic code and keep the model for the parts that need judgment. Keep
what you build portable, so you can switch agents or models when you need to.

The asymmetry is the point. Tokens spent building deterministic code are spent
once: if prices rise or the model changes, that code keeps working. Tokens
spent at runtime are owed again on every run, on whatever terms the provider
sets then.

## Why

Cost is one reason, and an uncertain one, since nobody outside the provider
knows whether today's prices will last. The other reasons hold at any price.

### Cost

- **Repetition flips the math.** One agent call is cheap next to an hour of
  engineering time. The same call running on every commit, every ticket, or
  every morning is a recurring bill, and when the work is mechanical, paying
  it again and again buys nothing a script would not give you once.
- **Pricing is not ours to control.** Flat-rate plans in particular may cost
  the provider more than they charge heavy users. If a workflow, a habit, or
  a product only makes sense at today's prices and limits, that dependence is
  a risk even if prices fall overall.

### Reliability

- **Latency.** A script returns in milliseconds. An agent loop takes seconds
  to minutes, every time.
- **Repeatability.** A script gives the same output for the same input. A
  model can give a different one, and "why did Tuesday's run differ?" may
  have no answer.
- **Drift.** You can version the prompt but not the model behind it. Pinned
  model versions exist, but the provider retires them on its own schedule, and
  an upgrade changes behavior while your prompt and code stay the same.
- **Availability.** Outages and rate limits on the provider's side become
  your outages.

### Independence

- **Portability.** A script runs for anyone who has the repo and its declared
  dependencies: a teammate with no LLM subscription, a CI runner, a machine
  with no network. It needs no LLM login, API key, or account. A workflow that
  only works through an agent only works for people who have that agent.
- **Knowledge stays legible.** Code's behavior is fixed by its text, so
  reading it tells you what it will do; reading a prompt does not. If the only
  description of a process is "ask the agent," the team loses the ability to
  reason about it, and finds that out when the agent is wrong or unavailable.
  This holds only if someone has read the script: an agent-written script
  nobody reviewed is as opaque as the agent.
- **Fungibility.** Switching agents or models — for price, for capability, or
  during an outage — should be a configuration change, not a rewrite. Harness
  features such as Claude Code's hooks, skills, and rules are worth using, but
  each is written for one vendor's agent, and logic that lives only there
  leaves with that vendor.

## Tests

Ask each question about a model call on the runtime path. A "no" is a warning
sign.

| Test       | Question                                                                   | A "no" means                                     |
| ---------- | -------------------------------------------------------------------------- | ------------------------------------------------ |
| **10x**    | Is it still worth it at ten times the price, or under a hard rate limit?   | It only pays off at today's prices and limits    |
| **Need**   | Does it need something a script cannot do: messy input or judgment?        | Deterministic code could do the whole job        |
| **Diff**   | If two runs on the same input disagreed, would that be harmless or caught? | Silent inconsistency in something that matters   |
| **Outage** | Could the work continue if the model were unavailable for a day?           | The work stops, with no fallback                 |
| **Share**  | Can a teammate with no LLM subscription or login of their own run it?      | Only people with their own LLM access can run it |
| **Swap**   | Could you move it to another agent or model by changing configuration?     | It is locked to one vendor's harness             |

A warning sign is not a veto. It is a reason to shrink the model's part until
only the judgment step depends on it. The exception is Diff: if an
inconsistency would be silent and would matter, add human review or keep the
model off the runtime path.

## When the model belongs on the runtime path

This is a principle about where the model sits, not against using it. A model
earns its place at runtime when the input is messy enough that a parser would
be more brittle than the model, when the task needs judgment (triage,
summarizing, classifying, reviewing), or when it runs too rarely to be worth
scripting — **and** either a failure is cheap and visible, or a human reviews
the output.

Even then, keep the model's job narrow. Let code do the fetching, filtering,
and formatting around the call, so that only the judgment depends on the
model.

## In practice

- **Graduate repeated work into a script.** When you notice an agent doing
  the same thing a third time, often enough to be worth scripting, and the
  steps have stopped changing, have the agent write the script, have a
  person read it, then run it. Add a test when the script will last and could
  regress; a throwaway script does not need one. A script costs maintenance
  too, and scripting a process that is still evolving freezes the wrong
  version.
- **Keep the harness layer thin.** A hook should call a script that also runs
  from the command line, and a rule or skill should point at guidance written
  in plain markdown that any agent can read, such as an `AGENTS.md`. Use a
  feature that exists on only one platform when it earns its place, but know
  what you would rebuild if you switched.
- **Have the agent call tools, not imitate them.** An agent that runs the
  test suite is better than one that reasons its way through what the tests
  would have said.
- **Leave the deterministic part behind.** At the end of an agent session,
  the useful result is a script, a test, or a doc that works without the
  agent, not a transcript of the agent doing the task.
