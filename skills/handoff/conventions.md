# Handoff conventions

A handoff is the note one agent session leaves for the next: a fresh session
after `/clear`, or another agent that picks up a piece of work while this one
carries on, or ends. It is a file, never text pasted into the reply.

A handoff is not a crash report. It exists because there was a natural place to
start over: the session's context was full, a task finished and its PR merged
so the next piece should start clean off `main`, or the worktree is about to be
torn down. Clearing wipes the session's memory of everything that was not
written down, and a handoff is what survives that on purpose.

## Where it lives

`$HOME/src/worktrees/<repo>/.handoffs/`, where `<repo>` is the repo's directory
name: beside that repo's worktrees, and outside every checkout of it. A worktree
is often torn down right after its handoff is written, and a note inside the
tree would go with it. Teardown removes only the worktree, never the directory
above it. A directory outside every checkout also means every session finds the
same notes, whichever tree it stands in.

When the machine-local guidance puts worktrees under a different root, the
handoffs go under that root, at `<root>/<repo>/.handoffs/`.

## What belongs in one

Start with the aim: what the work is trying to achieve and why, not just where
it stopped. A session that knows the goal can re-derive a plan; one that only
knows the last step cannot tell a detour from the route.

Then whatever the next session cannot reconstruct from the repository: what was
already tried and rejected, which measurement is load-bearing, which constraint
is not obvious from the code, and the next concrete step. Anything that _is_
reconstructable, such as commit history, a PR or a tracker issue, goes in as a
link rather than a copy, because a copy of live state rots and nothing
invalidates it.

Write it for a reader with none of this session's context. Name a worktree, a
branch or a path in full, with `$HOME` rather than `~`. When the worktree the
work happened in is being torn down, say which branch the receiver should enter
instead.

## Local, transient workstreams

Handoffs are how a workstream runs without a ticket. Plenty of work is small
enough that a tracker issue would cost more than it returns, including a local
`dev_docs/tasks/<name>_plan/` that is deliberately never pushed. A handoff is
what carries that between sessions.

The state-locality rule in `portable.md` still holds in general: state belongs
where its owner keeps it, and a handoff is a poor tracker for anything that
outlives a few sessions. Overriding that is allowed, and it works because it is
deliberate. Say in the file that you are doing it and why, so the next session
inherits a decision instead of guessing at an accident.

## Naming

`YYYY-MM-DD-<short-topic>.md`. A file that records a moment carries its date in
the name; that is what makes a stale handoff obviously stale rather than quietly
wrong.

## Front matter

Obsidian YAML:

```yaml
---
created: 2026-09-06
aim: "what this work is for, in a sentence"
repo: bestdan/<repo>
branch: bestdan/<branch> # omit if none yet, or name the trunk branch to merge into
task: PRE-123 # or a tracker URL; omit for a local workstream
pr: https://github.com/bestdan/<repo>/pull/<n> # once one exists
expires: "when #713 merges"
---
```

**Quote any value containing `#`.** In unquoted YAML a `#` after whitespace
starts a comment, so `expires: when #713 merges` parses as `when` and silently
loses the condition, which bites exactly when the condition is an issue or PR
number. Verified with `yaml.safe_load`.

`expires` is prose, not a date: "when #713 merges", "when the mini runs the
nightly successfully once". It is the sentence that tells the next session
whether the file still describes reality.

## Every handoff ends by deleting itself

Close each one with an explicit instruction to the reading agent, because an
agent that is not told to clean up will not:

> **When the work described above is done, delete this file.** It is a handoff,
> not a record. If what it says is worth keeping, it belongs in a commit
> message, a PR body, a decision under `dev_docs/decisions/`, a convention
> under `dev_docs/`, or the tracker. Move it there first, then delete this
> file.

A directory of stale handoffs is worse than an empty one: nothing marks which of
them still describes reality, so the next session reads all of them and trusts
none.

## Finding them

Nothing surfaces these automatically, and the directory sits outside the repo,
so no search of the checkout finds it. Look in it when you start work in a
repo, and before writing a new handoff, in case one for the same work exists.

A repo may still hold notes in its own `dev_docs/.handoffs/`, where handoffs
lived before 2026-10-14. Read them there; write new ones to the directory
above.
