---
name: handoff
description: Write a handoff, the note another agent or a fresh session picks the work up from, to $HOME/src/worktrees/<repo>/.handoffs/, outside every checkout, and reply with a one-line pointer to it. Use when the user says "handoff", "/handoff", "hand this off", "write a handoff", "a prompt for another agent", "pick it up with another agent", "so a fresh session can pick it up", or "before I /clear", before tearing down a worktree whose work is not finished, and on your own call when you are about to give the user text for them to paste into another agent. Not for the report that ends a task, which writing_about_code.md governs, and not for a command handed to the user to run.
---

# handoff

A handoff is a file, never text in the reply. The reply carries one line that
names the file, so the user can paste it into another agent without the `>`
prefixes, indentation and list markers a terminal copy brings along. The rule
is the `A handoff is a file` bullet in `portable.md`; these are its steps.

## 1. Pick the path

Write `$HOME/src/worktrees/<repo>/.handoffs/YYYY-MM-DD-<short-topic>.md`, where
`<repo>` is the repo's directory name, the same one its worktrees sit under.
Create the directory when it does not exist yet. When the machine-local
guidance puts worktrees under a different root, use `<that root>/<repo>/.handoffs/`.

Never write the note inside a checkout: not the worktree, which is often torn
down right after, and not a path inside the work, such as a story directory or
a package's `docs/`, where nothing looks for a handoff and the note gets
committed with the work.

Look in the directory first. A handoff for the same work may already exist, and
updating it beats leaving two that disagree.

## 2. Write the note

Read `${CLAUDE_PLUGIN_ROOT}/skills/handoff/conventions.md` before writing. The
parts a handoff most often misses are:

- the Obsidian front matter: `created`, `aim`, `repo`, `branch`, `task`, `pr`,
  `expires`, with any value holding a `#` quoted;
- the aim first, then what the receiver cannot reconstruct from the repo: what
  was tried and rejected, the load-bearing measurement, the non-obvious
  constraint, the next concrete step;
- links, not copies, for anything that lives elsewhere: a PR, an issue, a
  commit;
- the closing instruction to delete the file when the work is done.

Write it for a reader with none of this session's context. Name the branch the
receiver should enter in full, and any path with `$HOME` rather than `~`.

## 3. Reply with the pointer

Give the user one line in one fenced code block, and nothing around it that a
copy would pick up:

````
```
Read $HOME/src/worktrees/ai-scifi/.handoffs/2026-10-14-scene-3.md and follow it.
```
````

The path is absolute because the receiver may start in any checkout, and it
keeps `$HOME` rather than `~` so it still resolves inside a worktree-isolated
session. Above the
block, one sentence on what the handoff covers is enough. Do not repeat the
note's paths, task list or setup steps in the reply; they are in the file.

For more than one piece of work, write one file per piece and give one pointer
block per file.
