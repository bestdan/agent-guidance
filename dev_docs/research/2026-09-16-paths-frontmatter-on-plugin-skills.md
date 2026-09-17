---
created: 2026-09-16
question: "does a skill's paths: frontmatter load that skill when a plugin ships it, and does it fire before or after the write that matches"
feeds: ../designs/2026-09-16-dev-docs-write-hook.md
---

# `paths:` frontmatter on a plugin-shipped skill

## Question

Claude Code documents a `paths:` field on a skill as loading that skill
automatically when the session works with matching files. Does that hold for a
skill this plugin ships, and does it fire early enough to govern the write that
matched?

## Method

Two reviewers measured it independently on 2026-09-16, against Claude Code
2.1.274 on Linux, using a candidate `skills/dev-docs/SKILL.md` carrying
`paths: dev_docs/**`. Neither had the other result.

One ran headless sessions with `--plugin-dir` pointed at the worktree and read
the session debug log under `~/.claude/debug/`. The other traced a session that
performed a matching `Read` and inspected the tool calls that followed. Both
also read the 2.1.274 bundle at
`~/.local/share/claude/versions/2.1.274`.

The documentation under test is
[Claude Code skills](https://code.claude.com/docs/en/skills), which states that
`paths:` holds "glob patterns that limit when this skill is activated" and that
"Claude loads the skill automatically only when working with files matching the
patterns."

## Findings

### The field is inert for a plugin-shipped skill (verified)

Plugin skills load through a separate loader from the one that reads `paths:`.
The conditional split runs in the skill-directory loader, whose sources are
managed, user, synced, project and additional directories; plugin skills arrive
via `getPluginSkills` and the field is never consulted for them.

The debug log of a plugin session carries
`Loaded 4 skills from plugin agent-guidance` and no `conditional skills stored`
or `Activated conditional skill` line. A headless session that had touched no
`dev_docs/` file still listed `agent-guidance:dev-docs` among its offered
skills, which is the opposite of the documented restriction. A second session
that wrote a new `dev_docs/probe.md` reported no change.

Both log strings do exist in the 2.1.274 bundle (`rg -c` returns 2 for each),
so the code path is real and the plugin loader does not reach it.

### Where the field works, it is a restriction and it fires late

For a skill in `~/.claude/skills` or `.claude/skills`, the harness withholds
the skill from the skill list entirely until a `Read`, `Write` or `Edit`
touches a matching path, and lists it after that. It does not inject the
skill body.

All three file tools call the same activator, so a `Write` does trigger it.
The activation lands after the write that triggered it, so the content was
already generated. That nothing else auto-invokes the activated skill is
**inferred** from the bundle, not measured: the activator moves the skill into
the collection that feeds the command list.

The consequence is the reverse of the documented reading. For the first write
of a new file, a `paths:`-scoped skill fires less usefully than a plain
description-triggered one, because its description is not in context until
after that write.

### A plugin cannot ship rules either (verified)

`.claude/rules/` with `paths:` frontmatter is the mechanism the harness
documents for path-scoped instructions, and a plugin cannot ship it.
[anthropics/claude-code issue #14200](https://github.com/anthropics/claude-code/issues/14200)
requests it and is open, created 2025-12-16; issue #21163 was closed against it
as a duplicate on 2026-01-30.

### Token figures for the plugin's current payload (verified)

`wc -c` over 4, on 2026-09-16: `portable.md` 24651 → ~6162;
`portable-claude.md` 5262 → ~1315; `dev_docs_layout.md` 9625 → ~2406.

### `dev_docs/**` would match a nested directory (inferred)

The skill-directory loader strips a trailing `/**` and matches with
gitignore-style rules relative to the project root, so `dev_docs/**` also
matches `packages/x/dev_docs/`. Read from the bundle, not measured.

## Feeds

`../designs/2026-09-16-dev-docs-write-hook.md`, which abandoned the
`paths:`-scoped skill on the strength of the first finding and proposes a
`PreToolUse` hook instead.
