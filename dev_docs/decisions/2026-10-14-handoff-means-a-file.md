---
created: 2026-10-14
status: accepted
convention: ../conventions.md
---

# "Handoff" means a file, and a cue-phrase hook backs it

## Context

In an ai-scifi session the owner asked for a handoff so another agent could
pick up the work. The agent pasted a 40-line nested blockquote into the reply
instead. A copy out of the terminal carried every `>` and indent, and the
prompt could not be pasted cleanly (bestdan/agent-guidance#96).

The guidance gave the word three meanings. `portable.md` used "handoff" for a
note in `dev_docs/.handoffs/`, framed only around `/clear`.
`writing_about_code.md` used "hand-off" for the report that ends a task. The
copy rule and its hook used it for a `! <command>`. A model reading all three
had no one meaning to apply.

A replay of the detector over one laptop's transcripts on 2026-10-14 found 1
of 4,927 assistant messages that would block. It was a 52-line prompt for
another agent, which the rule forbids. The #96 session was not in that corpus,
so recall is unmeasured.

`dev_docs/.handoffs/` sat inside the checkout, and that failed two ways. The
owner often writes a handoff just before a worktree is torn down, and a
gitignored note in that worktree goes with it. A worktree-isolated session also
cannot write into the main checkout: on 2026-10-14 the Write tool refused it
with "Edit the worktree copy of this file instead", and a `PreToolUse` hook
refused the shell route. A write to a directory beside the worktrees, outside
every checkout, went through without a prompt.

## Decision

"Handoff" names one act: write the note to a file and reply with a one-line
pointer to it in one fenced block. The file goes in
`$HOME/src/worktrees/<repo>/.handoffs/`, beside the repo's worktrees and outside
every checkout, and `dev_docs/.handoffs/` keeps only older notes. The path is
named in `portable.md` itself rather than left to the machine-local guidance:
the guidance is one developer's, so naming that developer's layout is allowed,
and a named path leaves no case where a session has to ask. The conventions move from its
`README.md` into `skills/handoff/conventions.md`. The `portable.md` bullet
opens with that definition. The report heading becomes "End a report on what the reader must
do". The `!`-command hook is renamed `hooks/copyable-command.sh`. The
`agent-guidance:handoff` skill carries the steps, and `hooks/handoff-inline.sh`
blocks once on a fenced block or blockquote of more than three lines that
holds a cue phrase.

## Consequences

- Good, because the word now has one referent in every file a session reads,
  so a request for a handoff lands on the file.
- Good, because the skill's description triggers on the owner's phrasings, and
  `/handoff` invokes it directly.
- Good, because a note outside every checkout survives a worktree teardown,
  and every session reads the same directory whichever tree it stands in.
- Bad, because the path assumes the `$HOME/src/worktrees/` layout. A machine
  that puts worktrees elsewhere has to say so in its machine-local guidance,
  and the handoffs follow that root.
- Bad, because the cue phrases are a judgment in regex form. A long quoted log
  that says "pick up" blocks once, at the cost of one forced turn.
- Bad, because a handoff pasted as plain paragraphs has no block to detect, so
  only the prose rule carries it.

## Revisit when

The hook blocks a reply that was not a handoff more than occasionally, or
misses a pasted handoff that sits in a block. Either one changes the cue list
or the line threshold.

## Confirmation

`handoff-inline.test.sh` covers the #96 shape, the three-line boundary, long
blocks with no cue staying quiet, and the wiring. The `portable.md` bullet holds it on Codex, which
runs no `Stop` hook.

## Alternatives

- Extend `copyable-command.py`: rejected, because it checks a different rule
  and its findings and message would mix two fixes.
- A skill alone, with no hook: rejected, because the incident was the agent
  not recognising the case, and a skill does not load for a case it does not
  recognise.
- `/tmp/claude/<repo>/handoffs/`: rejected, because macOS empties `/tmp` at
  boot, and a handoff written before a restart would be lost.
- The worktree's own `dev_docs/.handoffs/`: rejected, because it goes with the
  worktree on teardown.
- Put the skill in `workflow-skills`: rejected, because the convention lives
  here and must reach Codex, which `workflow-skills` does not serve.
