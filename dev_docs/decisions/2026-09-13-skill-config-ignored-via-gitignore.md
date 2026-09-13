---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# Skill config under `dev_docs/` is ignored through `.gitignore` only

## Context

Three skills write machine-local config under `dev_docs/<skill>/` and used
three ignore channels: `co-review` appends to `.gitignore`,
`orchestrate-coders` writes to `.git/info/exclude`, `/task-config` uses a
local exclude for tracker handlers. `papercuts-plugin` ended up with
`dev_docs/orchestrate-coders/.coders.yml` tracked: a probe result and an
auth choice that are wrong on every other machine.

## Decision

A skill that needs per-machine config gets one directory named for the
skill, holding one hidden file, and that directory is listed in
`.gitignore`. No other channel.

## Consequences

- Good, because `.gitignore` travels with the repo, so a fresh clone knows
  the directory is local before anything writes to it.
- Good, because the entry is visible and doubles as documentation.
- Bad, because `orchestrate-coders` has to change, and the tracked
  `.coders.yml` has to be untracked.

## Revisit when

- A skill's config must not appear in the repo's `.gitignore` at all, for
  example in a repo whose `.gitignore` the user does not control; that would
  need a per-clone channel and a rule for when it is allowed.

## Confirmation

Nothing checks the channel. Review, and the tracked-file symptom when it is
missed.

## Alternatives

- **`.git/info/exclude`:** does not travel with a clone; produced the
  tracked probe file.
