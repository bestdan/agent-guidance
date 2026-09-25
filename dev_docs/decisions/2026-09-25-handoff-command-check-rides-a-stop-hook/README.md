---
created: 2026-09-25
status: accepted
convention: ../../conventions.md
---

# The hand-off command check rides a `Stop` hook and blocks the stop once

## Context

`portable.md` says a command handed to the user must survive a copy out of the
terminal. Some terminals keep a soft wrap as a real newline in the copy, and
the shell then runs each fragment as its own command. Issue #80 records one:
a 209-character `gh api` ran without its `--input` value, and the shell then
tried to execute the JSON file.

`portable.md` also says a rule a machine can decide belongs in a check, once
the corpus has been measured. The measurement is in
`references/2026-09-25-results.md`: 21 of 55 hand-off lines in one laptop's
transcripts ran over 100 characters. Scripts at a scratchpad path were among
them, so the rule's own fallback breaks when the script sits there.

A Claude Code hand-off has a fixed shape, a `!` prefix, so it is machine
detectable. It lives in the reply text. No `PreToolUse` event sees that text.
`Stop` does, through `last_assistant_message`, and it fires after the reply is
already on screen.

## Decision

Register `hooks/handoff-command.sh` on `Stop`. It reads the reply that just
ended and reports each `!` hand-off over 100 characters, ending in `\`, or
followed by more lines in its code block. It returns `decision: block` with the
findings as the reason, so the agent re-issues the commands at once, and a
`systemMessage` that tells the user a correction follows. On the forced turn
`stop_hook_active` is true, and the hook exits without output.

## Consequences

- Good, because the check fires without the model choosing to re-read the rule,
  on the shape that caused the incident.
- Good, because the loop is bounded by the harness's own flag: a correction
  that still breaks the rule ends the turn rather than blocking again.
- Bad, because the bad command is on screen before the hook runs. A user who
  pastes before the correction arrives gets no protection.
- Bad, because it is the plugin's first hook that blocks anything a guidance
  rule governs. What it blocks is the end of a turn, not a write or the user.
  `decision: block` is the one `Stop` output the agent reads, since plain stdout
  goes to the debug log.
- Bad, because a command handed over without `!` is invisible to it, so the
  prose still carries that case.
- Bad, because the 100-character limit is a guess at terminal width. The
  corrected command in issue #80 was 113 characters and survived.

## Revisit when

- Claude Code gains an event, or an output field, that can hold or rewrite the
  reply before it is displayed. That event would prevent the bad command rather
  than correct it.
- The block fires on hand-offs users paste without trouble, often enough to be
  noise. Then raise the limit, or report through `systemMessage` alone.
- Codex gains a `Stop` hook with the same block semantics. Then register it in
  `codex/hooks.json` too.

## Confirmation

`handoff-command.test.sh` covers each finding, the 100/101 boundary, the
`stop_hook_active` exit, the transcript fallback's turn boundary, and the
registration in `hooks/hooks.json`. The length and continuation cases were
confirmed to fail against a copy of the hook with each check disabled.

## Alternatives

- **`systemMessage` alone, no block:** rejected; it warns the user but the agent
  never learns the command broke, so nobody writes the corrected one.
- **A `PreToolUse` hook:** rejected; no tool call carries the reply text.
- **Prose only:** rejected; prose works only when the model re-reads it at the
  moment it writes the command, and a hook fires without that.
