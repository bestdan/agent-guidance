#!/usr/bin/env bash
# Stop hook. Reports a reply whose list numbers do not each name one item.
# `portable.md`: "Give each list label in a reply one meaning."
#
# What it catches, in list-labels.py beside this file: two numbered lists in one
# reply that share a number, and a numbered list inside a numbered item. Both
# leave a reply of "2" pointing at two items. Text in a code block does not
# count. What it does not catch is a repeated letter, (a) in two lists: a lone
# `i.` or `I.` at the start of a line reads as a letter, a roman numeral, or a
# pronoun, so the portable.md bullet carries letters alone.
#
# Why Stop, and why it blocks once: the same reasons as handoff-command.sh,
# whose header gives them. The labels live in the reply text, which only Stop
# sees, after the reply is on screen. `decision: block` is the one output that
# reaches the agent, and on the forced turn `stop_hook_active` is true, so a
# relabelled reply that still repeats a number cannot loop.
#
# Exit 0 on every path, including a payload or transcript this cannot read.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$(cat)"

case "$payload" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

PAYLOAD="$payload" python3 "$here/list-labels.py" 2>/dev/null

exit 0
