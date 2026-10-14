#!/usr/bin/env bash
# Stop hook. Reports a handoff pasted into the reply that just ended instead of
# written to a file. `portable.md`: "A handoff is a file, never text in the
# reply."
#
# What it catches, in handoff-inline.py beside this file: a fenced code block
# or a blockquote of more than three non-blank lines that addresses an agent
# picking up work ("pick up", "hand off", "enter the worktree", "follow it").
# The pointer the rule asks for is one line, so it passes. What it cannot catch
# is a handoff pasted as plain paragraphs: that has no shape a script can tell
# from any other reply, so the portable.md bullet still carries it. The cues
# are a judgment in regex form, and a long quoted log that happens to say
# "pick up" will block once; the cost is one forced turn.
#
# Why Stop, and why it blocks once: the same reasons as copyable-command.sh.
# The handoff lives in the reply text, which only Stop sees, and
# `decision: block` is the one output of a Stop hook that reaches the agent. On
# the continuation it forces, `stop_hook_active` is true and the program exits
# without a word, so the follow-up cannot loop.
#
# Exit 0 on every path, including a payload or transcript this cannot read.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$(cat)"

case "$payload" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

PAYLOAD="$payload" python3 "$here/handoff-inline.py" 2>/dev/null

exit 0
