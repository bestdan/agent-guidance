#!/usr/bin/env bash
# Stop hook. Reports a `! <command>` hand-off in the reply that just ended when
# it will not survive a copy out of the terminal. `portable.md`: "A command you
# hand me to run must survive a copy out of the terminal."
#
# What it catches, in handoff-command.py beside this file: a hand-off over 100
# characters, one ending in a `\` continuation, and one whose code block holds
# more lines after it. A `! ` line, a fenced line, and an inline code span all
# count. What it cannot catch is a command handed over without the `!` prefix,
# "paste this into your terminal": that has no shape a script can tell from any
# other code block, so the portable.md bullet still carries it.
#
# Why Stop and not PreToolUse. The command lives in the reply text, and no
# PreToolUse hook sees that text. Stop is the one event that does, and it fires
# after the reply is on screen. So this cannot keep a bad command from the
# user. It makes the agent re-issue a corrected one straight away, and its
# systemMessage tells the user one is coming, before they paste.
#
# Why it blocks the stop when every other guidance hook here only advises.
# `decision: block` is how a Stop hook reaches the agent at all: its plain
# stdout is shown to nobody. What it blocks is the end of the turn, not the
# user and not any write. It blocks once: on the continuation it forces,
# `stop_hook_active` is true and the program exits without a word, so a
# re-issued command that still breaks the rule cannot loop.
#
# The measurement that justified a check, and the choice of event:
# `dev_docs/decisions/2026-09-25-handoff-command-check-rides-a-stop-hook/`.
#
# Exit 0 on every path, including a payload or transcript this cannot read.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$(cat)"

# The one cheap exit. A payload without `last_assistant_message` sends the
# program to the transcript, so no other string test here can rule a finding
# out.
case "$payload" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

PAYLOAD="$payload" python3 "$here/handoff-command.py" 2>/dev/null

exit 0
