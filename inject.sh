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
# That is a claim about the PAYLOAD, not about the plugin's shape. The plugin
# does ship skills (today, skills/plugin-delivery), for material nobody needs
# until a symptom appears — where loading on demand is the right answer rather
# than the wrong one. The README's Versioning section carries what that costs.
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
# Which files to inject is decided by the caller, not here. Claude's hook
# (hooks/hooks.json) passes nothing and gets both. Codex's hook
# (codex/hooks.json) passes portable.md alone, because portable-claude.md names
# machinery Codex does not have — handing it over would be the exact cross-harness
# leak the two-file split exists to prevent.
#
# stdin carries the hook payload (session_id, cwd, …); nothing here needs it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -eq 0 ]; then
  set -- "$here/portable.md" "$here/portable-claude.md"
fi

# A provenance line is appended to the payload, naming the copy this session
# actually loaded. It exists because an installed plugin does not follow a merge
# and nothing in a session can tell: a local machine sits on the old commit
# until someone runs `claude plugin marketplace update` and `claude plugin
# update`, and a cloud environment is worse — its copy is frozen at the last
# environment build because a cached setup script is skipped entirely. Both
# failures are silent. `claude plugin list` does report the installed commit,
# but only to someone who runs it and knows to — and Codex has no listing at
# all, its generated AGENTS.md reading identically however old it is. The line
# does not make the session current; it puts what the session is running into
# its context, which is the part that was missing.
#
# It is computed here rather than written into the markdown, because a literal
# in the file would be identical upstream and installed — the same string on a
# fresh copy and a year-old one — and so could never signal staleness.
#
# GUIDANCE_ROOT rather than another argv entry: the Codex registration
# (codex/hooks.json) passes portable.md as $1, so argv is already a meaningful,
# caller-owned list of files to inject.
#
# Built in Python rather than printf: the payload is a whole markdown file with
# backticks, quotes and backslashes in it, and hand-quoted JSON mangles those
# silently — the result stays parseable, so the damage shows up as garbled
# guidance rather than an error.
GUIDANCE_ROOT="$here" python3 -c '
import datetime, json, os, re, sys

parts = []
for path in sys.argv[1:]:
    with open(path) as f:
        parts.append(f.read().rstrip("\n"))

root = os.environ["GUIDANCE_ROOT"]
name = os.path.basename(root)

# How the copy identifies itself, in the three shapes it comes in.
#
# A marketplace install lands at <cache>/agent-guidance/agent-guidance/<version>,
# and because plugin.json declares no `version`, Claude Code uses the short
# commit sha as that directory name. So the basename IS the commit — an
# inference from an undocumented layout, hence the hex test rather than a bare
# assumption, with the directory name reported verbatim when it does not match.
#
# `.git` may be a directory (a main checkout) or a file holding `gitdir: …` (a
# linked worktree), and a worktree is the normal shape of a checkout here — so
# the test is existence, not isdir, or a worktree would be offered a refresh
# that discards it.
if os.path.exists(os.path.join(root, ".git")):
    ident = "an editable working checkout (unreleased code)"
    refresh = ""
elif re.fullmatch(r"[0-9a-f]{7,40}", name):
    ident = "commit `" + name + "`"
    refresh = (" To refresh it: `claude plugin marketplace update agent-guidance`"
               " then `claude plugin update agent-guidance@agent-guidance`.")
else:
    ident = "version `" + name + "`"
    refresh = (" To refresh it: `claude plugin marketplace update agent-guidance`"
               " then `claude plugin update agent-guidance@agent-guidance`.")

# The mtime of a payload file, never of the plugin directory: the harness writes
# an `.in_use` marker inside the installed copy, which bumps the DIRECTORY mtime
# on ordinary use and would report every session as a fresh install.
try:
    stamp = datetime.date.fromtimestamp(
        os.path.getmtime(sys.argv[1])).isoformat()
    when = ", written " + stamp
except (OSError, IndexError):
    when = ""

parts.append(
    "## Provenance of this guidance\n\n"
    "It was delivered by the `agent-guidance` plugin: " + ident + when + ".\n"
    "The plugin root is `" + root + "`. That is the directory these files were"
    " delivered from. Where a rule below tells you to read a file from the"
    " plugin root, read it from there.\n"
    "Nothing inside a session can check whether that is the current commit, so"
    " when asked whether your guidance is up to date, report this line rather"
    " than assuming it is." + refresh + "\n"
    "A cloud session cannot be refreshed from inside at all — its copy is frozen"
    " at the last environment build, because a cached setup script is skipped"
    " entirely. That needs a human to invalidate the environment'"'"'s"
    " setup-script cache."
)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n\n".join(parts) + "\n",
    }
}))
' "$@"
