---
created: 2026-09-12
purpose: conventions for this directory
source: bestdan/agent-guidance dev_docs/.handoffs/README.md
---

# Handoffs (legacy)

New handoffs do not go here. Since 2026-10-14 they live in
`$HOME/src/worktrees/<repo>/.handoffs/`, or under `<root>/<repo>/.handoffs/` when
the machine-local guidance puts worktrees under a different root, beside the
repo's worktrees and outside
every checkout, so that tearing down a worktree cannot delete a note written for
the session that follows it. The conventions are in the plugin's
`agent-guidance:handoff` skill, `skills/handoff/conventions.md`. `portable.md` carries the rule, under
"A handoff is a file".

A note already here is still read where it is. When its work is done, delete
it, as its own closing line says.

## Why this directory is still ignored, twice

`.gitignore` keeps any note left here out of `git status` and out of commits.
`dprint.json` excludes them separately, because a dprint `includes` of
`**/*.{md,json,jsonc}` matches dot-prefixed paths and would fail the format
check on an unformatted note. Both entries stay until no repo holds notes here.

## Why this one file is tracked

This README stays tracked so that a session finding the directory learns where
handoffs went. It was added with `git add -f`, and Git applies `.gitignore` only
to untracked files, so it needs no negation pattern. `git add dev_docs/.handoffs/README.md`
is refused, because the pathspec names an ignored directory; `git add -A` and
`git commit -a` stage a change to it normally.

## Copies

A repo that copied the earlier version of this file keeps its `source:` line
and can replace its copy with this one.
