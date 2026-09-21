#!/usr/bin/env bash
# PreToolUse hook on Write and Edit: when a session is about to write a file
# under a dev_docs/ directory, put the layout's name in front of it before the
# tool call runs.
#
# Why a hook and not a skill. The obvious shape was a skill carrying
# `paths: dev_docs/**`, and it does not work. Two independent measurements
# against Claude Code 2.1.274 found the field inert for a PLUGIN-shipped skill:
# plugin skills load through getPluginSkills, while the conditional split that
# reads `paths:` runs in the skill-directory loader, whose sources are managed,
# user, synced, project and additional. The debug log for a plugin session
# carries "Loaded N skills from plugin agent-guidance" and no "conditional
# skills stored" line. Where the field does work, it is a restriction rather
# than a trigger: the skill is withheld until a matching path is touched, and
# activation lands AFTER the write that triggered it, which is the wrong side
# of the one event this guidance exists for.
# `dev_docs/research/2026-09-16-paths-frontmatter-on-plugin-skills.md`
# is the measurement.
#
# A PreToolUse hook has neither problem. It is harness-driven, so no judgment
# decides whether it fires; it runs BEFORE the tool call, so the layout is in
# context while the file is still being written rather than after; and a session
# that never touches the directory never runs this script at all.
#
# That last part is the handler's `if` field in hooks.json, not this script.
# Registered on the bare `Write|Edit` matcher, the script spawned on every edit
# and discarded the payload after the fact: measured at 3 spawns for 3 writes
# under src/. With `if`, the same probe spawns 0. The path test below stays as
# the tested layer and as defence in depth, because `if` is a condition this
# repo's suite cannot exercise.
#
# `if` takes ONE rule. `Write(dev_docs/**)|Edit(dev_docs/**)` is accepted and
# then matches nothing, silently: measured at 0 spawns for a write directly
# under dev_docs/, where the same probe with `Write(dev_docs/**)` alone spawns
# 1. hooks.json therefore registers two handlers, one per tool, rather than one
# handler with an alternation.
#
# The glob is `**/dev_docs/**`, and the leading `**/` is load-bearing.
# `dev_docs/**` anchors at the project root: measured, it fires for
# dev_docs/x.md and not for packages/x/dev_docs/x.md. The path test below has
# never had that limit, so before `if` gated the spawn it covered any depth;
# the narrowing is what made the anchor matter.
#
# It emits a pointer, never the layout itself. dev_docs_layout.md is ~2,400
# tokens and a second copy here would drift from the file the checker names in
# its own failure output.
#
# Once per session, not once per write. A hook fires on every matching tool
# call, and a plan that writes nine records under dev_docs/ would otherwise pay
# for nine copies of the same paragraph. The marker file is keyed on the
# session id so a second session in the same repo still gets it.
#
# The marker lands in /tmp/claude in practice, not in the payload's
# scratchpad_dir. The hooks reference documents that field on the PreToolUse
# payload, and a live probe against 2.1.274 did not receive it: the marker for
# session f2761851 appeared under /tmp/claude, which is the fallback. So the
# fallback is the ordinary path and scratchpad_dir is the optimisation, which is
# the reverse of how it reads. The cost is that a zero-byte marker per session
# accumulates in /tmp/claude, where nothing prunes it.
#
# Never blocks. `permissionDecision: deny` was the alternative and is wrong
# here: the layout is guidance, not a safety rule, and the checker
# (scripts/dev-docs-layout.py) is the enforcement tier that can afford to say
# no. A hook that denied a write would also deny the write that FIXES a layout
# violation.
#
# Exit 0 on every path, including a malformed payload. A PreToolUse hook that
# exits nonzero is a blocked tool call, and failing a session's write because
# this script could not parse its own input would be a far worse outcome than
# silently not offering a pointer.
#
# The program is dev-docs-context.py beside this file, not a `python3 -c`
# argument. That argument was parsed by nothing: shellcheck sees one opaque
# string, and a python checker sees no file to open. So a truncated program was
# a hook that said nothing on every payload, with nothing reporting it. A
# missing or unparsable `.py` file fails the same silent way, because the
# never-block rule above is unconditional; what changes is that the failure is
# findable before it ships.
# `dev_docs/decisions/2026-09-20-hook-python-lives-in-a-file-beside-the-shell.md`
# is the record.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload="$(cat)"

PAYLOAD="$payload" GUIDANCE_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$here")}" \
  python3 "$here/dev-docs-context.py" 2>/dev/null

exit 0
