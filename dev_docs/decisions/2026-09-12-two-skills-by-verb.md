---
created: 2026-09-12
status: accepted
convention: ../conventions.md
---

# Two skills split by verb, not one combined conventions skill

## Context

The reviewing and PR-authoring conventions moved out of `bestdan/dotfiles`
into this plugin as three content files: `writing_about_code.md` for the
shared prose register, `authoring_pull_requests.md` for what a PR adds, and
`reviewing.md` for what a review checks. A skill has to load them at the
right moment, and a skill's content is charged to the session's context
window every time it fires. `dotfiles/agents/AGENTS.md` had already drawn a
distinction between the two verbs: the prose register "applies without being
read", the PR file is "read at PR time, not at session start".

## Decision

Two skills, `skills/authoring` and `skills/reviewing`, each reading the shared
register file and then its own verb's file. Neither loads at session start
and neither reads the other verb's file.

## Consequences

- Good, because each verb pays only for its half: a review never loads the
  PR-body grammar and a PR never loads the finding format.
- Good, because the split preserves the distinction `AGENTS.md` already made
  between register and PR grammar.
- Bad, because two triggers can each fail to fire, and a skill that does not
  fire loads nothing. The `portable.md` Rules bullets that name the files are
  the backstop for a harness without skills or a trigger that misses.

## Revisit when

- Either trigger is measured missing on real sessions: a review or a PR
  produced without the conventions in context, more than occasionally.
- The harness starts charging skill descriptions differently, so that two
  descriptions cost more than one skill's content would.

## Confirmation

`skills.test.sh` proves each skill's front matter parses, and
`skills-selftest.test.sh` proves that check fails when it should. Nothing
tests that a trigger fires; that rests on the description text.

## Alternatives

- **One combined skill:** charges every session the half it is not doing.
- **Inject the files at session start:** always present, always paid for, on
  every turn of every session.
