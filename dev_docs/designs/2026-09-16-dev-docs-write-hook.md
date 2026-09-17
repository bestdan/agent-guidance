---
created: 2026-09-16
status: proposed
---

# Carry conditional guidance on a PreToolUse hook, starting with `dev_docs/`

Every carrier this plugin has decides before the task is known: the
`SessionStart` hook pays for its payload in every session, and a skill loads
only when the model judges its description to match. Guidance with a
mechanical trigger has nowhere to go, so it sits in `portable.md` as a bullet
telling the model to read a file. A `PreToolUse` hook on `Write` and `Edit` is
a third carrier that the harness fires on the event itself, before the tool
call runs. This proposes adopting it, with `dev_docs_layout.md` as the first
case.

## What is true today

Carriers, measured 2026-09-16, sizes as `wc -c` over 4:

| Carrier                  | Fires when                 | Cost per session   |
| ------------------------ | -------------------------- | ------------------ |
| `portable.md`            | always                     | ~6,162 tokens      |
| `portable-claude.md`     | always                     | ~1,315 tokens      |
| `skills/authoring`       | model judges a description | name + description |
| `skills/reviewing`       | model judges a description | name + description |
| `skills/plugin-delivery` | model judges a description | name + description |

`dev_docs_layout.md` is ~2,406 tokens and most sessions never write under
`dev_docs/`, so it is not injected. It is reached by the
**`Writing anything under dev_docs/`** bullet in `portable.md`, which names the
file and asks the model to read it. That bullet wraps a condition that is not a
judgment: a path either is under `dev_docs/` or is not.

The obvious mechanism for that condition does not exist here. A skill accepts
`paths:` frontmatter, and the field is inert for a skill a plugin ships; where
it does work it withholds the skill until a matching path is touched and
activates it after the write that touched it, which is the wrong side of the
event. A plugin cannot ship `.claude/rules/` either. Both results, with their
evidence, are in
[`../research/2026-09-16-paths-frontmatter-on-plugin-skills.md`](../research/2026-09-16-paths-frontmatter-on-plugin-skills.md).

What does work: a `PreToolUse` hook returns
`hookSpecificOutput.additionalContext`, runs before the tool call, and a
plugin's `hooks/hooks.json` uses the same schema as a settings file. This repo
already ships that file for `SessionStart`.

Verified live, not from the reference alone. A headless session on 2.1.274,
run with `--plugin-dir` at this worktree, was asked to create
`dev_docs/probe-note.md` in an empty directory. It wrote the file and its reply
said: "I note that the hook is reminding me about dev_docs conventions: files
should either be live (undated, kept current) or records (dated
`YYYY-MM-DD-<slug>.md`, allowed to go stale)." That is this hook's
`additionalContext`, in front of the write that triggered it.

## Proposal

Add `hooks/dev-docs-context.sh`, registered on `PreToolUse` with the matcher
`Write|Edit`. When the target path has a `dev_docs` segment, it returns
`additionalContext` naming `dev_docs_layout.md`, the directory's own
`README.md`, and the checker. Otherwise it prints nothing.

What the rest of the system sees:

- `portable.md` is unchanged, and remains the route for Codex and the backstop
  here.
- `inject.sh` is unchanged, and no session's always-on payload grows.
- A session that never writes under `dev_docs/` never runs the script: the
  handlers carry an `if` condition, so the narrowing happens at dispatch.
- `dev-docs-context.test.sh` pins the boundaries, including the wiring in
  `hooks/hooks.json`, and runs from `scripts/run-tests.sh` with the rest.

## Decisions

### A hook rather than a skill, because the trigger is an event

The guidance is needed at one moment: the write. A skill is offered to the
model, which then decides; a `PreToolUse` hook is dispatched by the harness on
the event and runs before the tool call. The rejected alternative was a skill
carrying `paths: dev_docs/**`, which was built, measured and abandoned.

### It emits a pointer, never the layout

`additionalContext` names `dev_docs_layout.md` and stops. Inlining ~2,406
tokens would put the whole layout in front of every first write, which is the
eager cost the bullet exists to avoid, and a second copy would drift from the
file `scripts/dev-docs-layout.py` names in its own failure output.

### Once per session, not once per write

A hook fires on every matching tool call, so a plan writing nine records under
`dev_docs/` would otherwise pay for nine copies of the same paragraph. A marker
file keyed on `session_id` holds it to one, and an unwritable marker directory
repeats the pointer rather than losing it.

The marker lands in `/tmp/claude`, not in the payload's `scratchpad_dir`. The
hooks reference documents that field on the `PreToolUse` payload and the live
probe below did not receive it, so the fallback is the ordinary path. One
zero-byte file per session accumulates there, and nothing prunes it.

### It never denies the write

`permissionDecision: deny` was the alternative. The layout is guidance, and
`scripts/dev-docs-layout.py` is the tier that can afford to say no, because it
runs over a finished tree rather than mid-edit. A denying hook would also block
the write that fixes a violation. For the same reason the script exits 0 on
every path, including a payload it cannot parse: a nonzero exit from a
`PreToolUse` hook blocks the tool call.

### The narrowing is in `if`, and the path test in the script backs it up

The handler's `if` field takes permission-rule syntax, and it is what stops the
script running on every edit in the repo. Measured against 2.1.274 with the
script instrumented to log each spawn: on the bare `Write|Edit` matcher, three
writes under `src/` produced three spawns; with `if`, the same probe produced
none, and a write under `dev_docs/` still produced one.

An earlier revision of this design rejected `if` on the grounds that a
condition expressed there cannot be exercised by `dev-docs-context.test.sh`.
That reason was too strong. The condition cannot be unit-tested, but it can be
measured in a live session, and it costs nothing to keep the script's own path
test as the tested layer underneath it. Both are kept: `if` decides whether the
process starts, the script decides whether it speaks.

The script's own test is on segments, and `dev_docs` must not be the last one.
A substring test fires on `dev_docs_layout.md` at a repo root, which is this
plugin every time someone edits the convention itself.

### Two handlers, because `if` takes one rule

`Write(dev_docs/**)|Edit(dev_docs/**)` is accepted and matches nothing. It is
not a parse error and nothing is logged; the hook simply never fires. Measured
the same way: that alternation produced zero spawns for a write directly under
`dev_docs/`, where `Write(dev_docs/**)` alone produced one. So the entry
registers two handlers on the same matcher, one per tool.

`dev-docs-context.test.sh` pins both conditions and fails an alternation,
because a single `if` reads as the tidier config and would be the natural
thing for a later editor to collapse it back to.

### `Write|Edit`, not `Read`

`Read` also matches paths and fires far more often. A session reading an
existing record is not about to produce a misfiled one, and the pointer would
land in front of ordinary browsing.

## Not decided here

- **Whether other conditional guidance follows.** The sandbox material in
  `CLAUDE_ONLY.md` is the largest remaining block, and its trigger is a command
  that already failed, which no matcher expresses. Nothing else in the plugin
  has a mechanical trigger today.
- **Whether the pointer's wording earns its length.** It is measured only by
  whether sessions then read the file, which needs live use.
- **Whether Codex grows an equivalent.** Its `hooks.json` registers
  `SessionStart` alone, so the bullet remains its only route.

## Graduation

The measurement this design needed has been made and is recorded in
`../research/2026-09-16-paths-frontmatter-on-plugin-skills.md`, so nothing here
waits on evidence. Delete this design in the PR after the one that lands it.

- Decision records, one each: hook rather than skill; pointer not payload;
  once per session; never denies; `if` narrows and the script backs it up; two
  handlers because `if` takes one rule; `Write|Edit` rather than `Read`.
- Conventions: the README ships table, and a line in `dev_docs/conventions.md`
  naming the hook as a carrier shape and what it costs.
