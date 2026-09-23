---
created: 2026-09-16
status: accepted
convention: ../conventions.md
---

# Guidance with a mechanical trigger rides a `PreToolUse` hook, not a skill

> [!NOTE] 2026-09-22: The rejected `SessionStart`-writes-rules alternative
> below assumed the consumer repo as the destination. A hook can instead write
> the user-level `~/.claude/rules/`, which is how Betterment's `the-book` CLI
> delivers its standards, and a `paths:`-scoped rule written there at
> `SessionStart` does load in that same session on 2.1.280. An always-on rule
> written the same way loads one session late. Measured in
> `../research/2026-09-22-session-start-written-rules/`. This does not change
> the decision: the hook here still covers the first write of a new file,
> which a `paths:` rule misses, and it runs where `~/.claude` is not ours.

## Context

Every carrier this plugin had decided before the task was known. The
`SessionStart` hook pays for its payload in every session, and a skill loads
only when the model judges its description to match. `dev_docs_layout.md` is
about 2,406 tokens and most sessions never write under `dev_docs/`, so it was
reached by a bullet in `portable.md` asking the model to read the file. That
bullet wraps a condition that is not a judgment: a path either has a `dev_docs`
segment or it does not.

The mechanism a skill offers for that condition does not work here. `paths:`
front matter is inert on a skill a plugin ships, and where it does work it
activates the skill after the write that touched the path, which is the wrong
side of the event. A plugin cannot ship `.claude/rules/` either. The evidence
is in `../research/2026-09-16-paths-frontmatter-on-plugin-skills.md`.

## Decision

Carry that guidance on a `PreToolUse` hook. `hooks/dev-docs-context.sh` is
registered on the `Write|Edit` matcher and returns
`hookSpecificOutput.additionalContext` naming `dev_docs_layout.md`, the
directory's own `README.md`, and the checker. The harness dispatches it on the
event, before the tool call runs, so the guidance arrives in front of the write
rather than being offered to the model.

## Consequences

- Good, because the trigger is evaluated by the harness rather than by the
  model, so a write under `dev_docs/` cannot miss the layout.
- Good, because no session's always-on payload grows: `portable.md` and
  `inject.sh` are unchanged, and a session that never writes under `dev_docs/`
  never runs the script.
- Bad, because another carrier is another thing that can skew from the payload
  and the skills, which the README's Versioning section already describes.
- Bad, because the route is Claude Code only. Codex registers `SessionStart`
  alone, so the `portable.md` bullet remains its route there and the backstop
  here.

## Revisit when

- `paths:` front matter starts working on a plugin skill and fires before the
  write rather than after.
- A plugin can ship `.claude/rules/`, which would express the same condition as
  config rather than as a script.

## Confirmation

`dev-docs-context.test.sh` pins the script's behaviour and the wiring in
`hooks/hooks.json`, and runs from `scripts/run-tests.sh` with the rest. A live
headless session on 2.1.274 confirmed the context arrives in front of the
write.

## Alternatives

- **A skill carrying `paths: dev_docs/**`:** built, measured and abandoned; the
  field is inert for a plugin skill, and where it works it fires late.
- **The `portable.md` bullet alone:** what existed before; it costs nothing at
  dispatch but leaves the trigger to the model's judgment.
- **A `SessionStart` hook that writes rule files into the consumer repo:**
  rejected, and it is the option the `.claude/rules/` limit above invites.
  Every carrier here delivers content without committing anything to a
  consumer repo, and a hook that materialises `.claude/rules/` leaves
  untracked files in a repo that never asked for them.
