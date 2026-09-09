#!/usr/bin/env bash
# SessionStart hook: injects portable.md and portable-claude.md into the
# session as context.
#
# Why a hook and not a CLAUDE.md. Claude Code reads user-level preferences from
# ~/.claude/CLAUDE.md only, and in a cloud session (claude.ai/code) that file is
# not mine — HOME is the container's, ~/.claude is harness-owned, and
# sync_claude.sh never ran. A plugin is the one channel that does reach those
# sessions (the container installs enabled plugins from account settings at
# startup), and a plugin's own root CLAUDE.md is explicitly NOT loaded as
# context — "plugins contribute context through skills, agents, and hooks". A
# skill would only load when Claude judged it relevant; preferences have to be
# there from the first turn. So: SessionStart, which is the always-on carrier.
#
# This is the sole carrier of the portable half, on every machine including my
# laptop. That is deliberate: if agents/AGENTS.md also imported portable.md,
# every laptop session would load it twice. The machine-local half stays in
# AGENTS.md and reaches only machines that sync the dotfiles.
#
# Two files, not one. Some portable rules name Claude-only machinery
# (AskUserQuestion, the Agent and Workflow tools, the model tiers) that Codex
# cannot act on. Those live in portable-claude.md. Both files are injected here,
# because every Claude session is a Claude session; sync_codex.sh concatenates
# only portable.md into ~/.codex/AGENTS.md. The order is fixed — portable.md,
# then portable-claude.md — so the injected context is deterministic and a diff
# of two sessions' context is a diff of the files, not of the hook.
#
# A missing file is a failure, never a skip. `set -e` and Python's open() both
# see to that: a plugin that silently injected one file of two would be the
# exact silent loss the rule inventory exists to catch.
#
# stdin carries the hook payload (session_id, cwd, …); nothing here needs it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Built in Python rather than printf: the payload is a whole markdown file with
# backticks, quotes and backslashes in it, and hand-quoted JSON mangles those
# silently — the result stays parseable, so the damage shows up as garbled
# guidance rather than an error.
python3 -c '
import json, sys

parts = []
for path in sys.argv[1:]:
    with open(path) as f:
        parts.append(f.read().rstrip("\n"))

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n\n".join(parts) + "\n",
    }
}))
' "$here/portable.md" "$here/portable-claude.md"
