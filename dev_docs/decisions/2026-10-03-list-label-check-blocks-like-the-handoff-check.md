---
created: 2026-10-03
status: accepted
convention: ../conventions.md
---

# The list-label check rides `Stop` and blocks once, like the hand-off check

## Context

The user answers a reply by its labels, as in "do 2" or "3b". One reply listed four
numbered steps and then three numbered decisions, so "2" named a step and a
decision at once. The user could not answer it by number.

`portable.md` says a rule a machine can decide belongs in a check, once the
corpus has been measured. The shape is machine detectable: a numbered list item
at the margin whose number already appeared, or a numbered item inside a
numbered item. A scan of one laptop's transcripts on 2026-10-03 ran the check
over the final message of each turn, which is what `last_assistant_message`
carries. Of 1,987 turns, 299 held a numbered list and 13 were flagged. A sample
of the flagged replies showed real collisions: a numbered list of findings or
steps, then a numbered list of questions. The one doubtful case held two
procedures under separate headings, each numbered from 1.

## Decision

Register `hooks/list-labels.sh` on `Stop`, beside `hooks/handoff-command.sh`,
with the same contract: `decision: block` once, quiet when `stop_hook_active`
is true, exit 0 on every path. Both programs read the reply through
`hooks/stop_turn.py`, which was moved out of `handoff-command.py` for the purpose.

The check covers numbers only. A letter label at the start of a line is
ambiguous: `i.` is a letter, a roman numeral, or a pronoun. The `portable.md`
bullet carries letters.

## Consequences

- Good, because a reply that cannot be answered by number is re-issued before
  the user answers it.
- Bad, because the re-issue repeats the reply, and the earlier version stays on
  screen. The `systemMessage` tells the user to answer the later one.
- Bad, because two procedures under separate headings, each numbered from 1,
  are flagged. The user can name one of them by heading, so this is a false
  positive. It was one case in the sample, and the relabel costs one turn.

## Revisit when

- Replies with separate numbered procedures turn out to be common. Exempting a
  list that follows a heading would then be the fix.
- Claude Code gives a `Stop` hook a way to reach the agent without blocking.

## Confirmation

`list-labels.test.sh` runs the check on the reply that prompted it, with the
decisions numbered and then lettered, and asserts that `hooks/hooks.json`
registers the hook on `Stop`.

## Alternatives

- **Advise rather than block:** a `Stop` hook's plain stdout reaches nobody,
  and a `systemMessage` reaches only the user, who did not write the reply.
- **Check letters too:** a lone `i.` cannot be told from a roman numeral or a
  pronoun, so a letter check would flag correct replies.
