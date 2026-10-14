---
name: handoff
description: Write a handoff, the note another agent or a fresh session picks the work up from, to a file under dev_docs/.handoffs/ and reply with a one-line pointer to it. Use when the user says "handoff", "/handoff", "hand this off", "write a handoff", "a prompt for another agent", "pick it up with another agent", "so a fresh session can pick it up", or "before I /clear", and on your own call when you are about to give the user text for them to paste into another agent. Not for the report that ends a task, which writing_about_code.md governs, and not for a command handed to the user to run.
---

# handoff

A handoff is a file, never text in the reply. The reply carries one line that
names the file, so the user can paste it into another agent without the `>`
prefixes, indentation and list markers a terminal copy brings along. The rule
is the `A handoff is a file` bullet in `portable.md`; these are its steps.

## 1. Pick the path

- **The repo has `dev_docs/.handoffs/`:** write
  `dev_docs/.handoffs/YYYY-MM-DD-<short-topic>.md` there, in the repo where the
  work lives.
- **It does not, or this session cannot write there:** an isolated worktree
  session cannot write into a sibling worktree, for one. Write
  `/tmp/claude/handoffs/YYYY-MM-DD-<short-topic>.md`, which every session on
  the host can read. Tell the user that path in the reply, and add a first
  step to the note telling the receiver to move it into its own
  `dev_docs/.handoffs/` when that exists.

Do not invent a path inside the work itself, such as a story directory or a
package's `docs/`: nothing looks there for a handoff, and the note gets
committed with the work.

## 2. Write the note

Read `${CLAUDE_PLUGIN_ROOT}/dev_docs/.handoffs/README.md`, or the copy in the
repo, before writing. It carries the conventions, and the ones a handoff most
often misses are:

- the Obsidian front matter: `created`, `aim`, `branch`, `task`, `pr`,
  `expires`, with any value holding a `#` quoted;
- the aim first, then what the receiver cannot reconstruct from the repo: what
  was tried and rejected, the load-bearing measurement, the non-obvious
  constraint, the next concrete step;
- links, not copies, for anything that lives elsewhere: a PR, an issue, a
  commit;
- the closing instruction to delete the file when the work is done.

Write it for a reader with none of this session's context. Where the receiver
must enter a worktree or a branch, name it in full, with `$HOME` rather than
`~`.

## 3. Reply with the pointer

Give the user one line in one fenced code block, and nothing around it that a
copy would pick up:

````
```
Read dev_docs/.handoffs/2026-10-14-kindle.md and follow it.
```
````

Use the path as the receiver will resolve it: repo-relative when it starts in
that repo, absolute for `/tmp/claude/handoffs/`. Above the block, one sentence
on what the handoff covers is enough. Do not repeat the note's paths, task
list or setup steps in the reply; they are in the file.

For more than one piece of work, write one file per piece and give one pointer
block per file.
