---
created: 2026-10-14
status: accepted
convention: ../../portable.md
---

# Describe a mechanism only in the repo that ships it

## Context

Agent instructions reach a session from three repos: this plugin, a
machine's `AGENTS.md` in `bestdan/dotfiles`, and the plugins that ship
tools, such as `bestdan/workflow-skills`. Each repo can describe any
mechanism. Nothing links a description to the code it describes.

Worktree entry shows the cost. `bestdan/workflow-skills` owns all of the
code: the `WorktreeCreate` hook that places worktrees and hands one back on
`EnterWorktree` `name`, the guard that refuses writes into a worktree the
session has not entered, and co-review's route to a PR's branch. On
2026-10-14 the descriptions of that code were in two other repos:

- `portable-claude.md:37` here told agents to enter another worktree with
  `EnterWorktree` (`path`). For every worktree the hook creates, that call
  raises a prompt that `claude -p` and Remote Control cannot answer. The line
  had been correct before the plugin's layout moved worktrees out of
  `.claude/worktrees/`. Nothing flagged it when the layout changed.
- `agents/CLAUDE_ONLY.md` in dotfiles named `EnterWorktree` 8 times. Most of
  those lines described the plugin's behaviour, not anything specific to the
  machine.
- The design for the next change to that code was in dotfiles, while every
  line it proposed lands in workflow-skills.

The full inventory is in bestdan/workflow-skills#992.

## Decision

A mechanism is described only in the repo whose code provides it. Other
repos state the rule and its result, and point at the owning repo's doc for
the steps. A value a machine sets stays with that machine. When a rule has
to be in context in every session, the owning repo delivers it, for example
with a `SessionStart` hook.

## Consequences

- Good, because a change to the code and a change to its description land
  in one PR, so review sees both.
- Good, because a rule in another repo that names no tool call cannot be made
  false by that tool changing.
- Bad, because a pointer is weaker than inline text. A skill or doc is read
  only when an agent loads it, while an `AGENTS.md` line is in every session.
  The owning repo has to deliver what must always be in context, and a repo
  that has no delivery hook has to add one.
- Bad, because an instruction file now sends its reader somewhere else for
  the steps, which costs one read.
- Bad, because rules already in this plugin break it. In `portable.md`, the
  `git status` bullet describes `agents/guard_noop_git_add.py`, the
  `scratch.py` bullet describes `setup.sh`, and the git-fixture bullet
  describes `setup.sh` and `agents/test_prelude.sh`. In `portable-claude.md`,
  the env-prefix bullet describes `agents/guard_env_prefix_git.py`. A follow-up
  cuts each one to the rule and the hook's name, and moves the behaviour to
  `bestdan/dotfiles`.

## Revisit when

- Agents in sessions that have only the pointer keep choosing the wrong
  mechanism, and the owning repo cannot deliver the rule itself.
- A check can compare a copy with its source across repos. A copy that a test
  keeps in sync is safe, and the rule would then forbid less.

## Confirmation

Nothing mechanical. A check in one repo cannot see the code in another, so it
cannot tell a mechanism description from a rule. Review holds this up, using
the test in the `portable.md` bullet: if a change to another repo's code can
make a sentence false, the sentence belongs in that repo. Naming the owning
repo's doc, or the hook that enforces a rule, is exempt; describing what that
hook does is not.

## Alternatives

- **Keep the copies, and update them in the same change.** This is what
  happened, and it failed: the change to the layout did not touch
  `portable-claude.md`, because nothing tied the two together.
- **Generate the copies from the source**, the way `sync_codex.sh` in dotfiles
  builds `~/.codex/AGENTS.md` from this plugin. That works for whole files on
  a machine that has the source installed. It does not work for single
  sentences inside a hand-written file.
