#!/usr/bin/env bash
# Tests hooks/comment-key-context.sh, the PreToolUse hook that reports a
# tracker key added in a code comment.
# Run: bash comment-key-context.test.sh
#
# The cases are the boundaries, not the happy path. This hook runs on every
# Write and Edit in every repo a session touches, so its failure mode is a
# false positive in somebody else's codebase, on text they did not write. Most
# of what follows pins silence.
#
# The added-lines rule is the half that cannot be read off the script's output
# in normal use: a hook that scanned the whole payload would pass every case
# that only ADDS a key, and differ from this one exactly on the writes that
# touch a file already carrying one.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook="$self/hooks/comment-key-context.sh"
work="$(make_workdir comment-key-context-test)"
trap 'rm -rf "$work"' EXIT
fail=0

check() {
  local desc=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    printf 'ok   %s\n' "$desc"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$desc" "$want" "$got"
    fail=1
  fi
}

# Reads a payload on stdin and echoes "context" when the hook reported a
# finding, "silent" when it said nothing, or "notjson" when what it printed
# cannot be parsed.
verdict() {
  bash "$hook" > "$work/out" 2>/dev/null
  PATH_OUT="$work/out" python3 -c '
import json, os, sys
raw = open(os.environ["PATH_OUT"]).read().strip()
if not raw:
    print("silent")
    sys.exit()
try:
    body = json.loads(raw)
except ValueError:
    print("notjson")
    sys.exit()
out = body.get("hookSpecificOutput") or {}
print("context" if out.get("additionalContext") else "silent")
'
}

# An Edit payload: the file path, the replaced text, the replacing text.
edit() {
  PY_PATH=$1 PY_OLD=$2 PY_NEW=$3 python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "tool_name": "Edit",
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "old_string": os.environ["PY_OLD"],
        "new_string": os.environ["PY_NEW"],
    },
}))
' | verdict
}

# A Write payload. The file on disk is the old text, so the caller creates it
# first (or does not, for a new file).
write() {
  PY_PATH=$1 PY_NEW=$2 python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "tool_name": "Write",
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "content": os.environ["PY_NEW"],
    },
}))
' | verdict
}

# --- 1. the case the hook exists for ---
check "an added # comment carrying a key is reported" context \
  "$(edit "$work/a.py" "x = 1" "# see PRE-999 for why
x = 1")"
check "an added // comment carrying a key is reported" context \
  "$(edit "$work/a.js" "const x = 1;" "// ENG-42 asked for this
const x = 1;")"

# --- 2. TODO is the exception the rule names ---
# There the key names outstanding work rather than citing a source, so a guard
# that fired here would be enforcing more than portable.md says.
check "a TODO carrying a key is silent" silent \
  "$(edit "$work/a.py" "x = 1" "# TODO(PRE-999): drop this once the migration lands
x = 1")"

# --- 3. code is not a comment ---
# A key in a string, a variable or a branch name is not the thing the rule is
# about, and a scan that did not find the comment marker first would report all
# three.
check "a key in a string literal is silent" silent \
  "$(edit "$work/a.py" "x = 1" 'ticket = "PRE-999"')"
check "a key in a URL in code is silent" silent \
  "$(edit "$work/a.py" "x = 1" 'url = "https://example.com/ABC-123"')"

# --- 4. added lines only ---
# The whole design question. A key that pre-dates the rule is not a finding,
# and a scan of the payload alone cannot tell it from one being added.
printf '# legacy note, see PRE-1\nx = 1\n' > "$work/legacy.py"
check "a Write leaving an existing key untouched is silent" silent \
  "$(write "$work/legacy.py" "# legacy note, see PRE-1
x = 2
")"
check "a Write adding a key to a file that already had one is reported" context \
  "$(write "$work/legacy.py" "# legacy note, see PRE-1
# and now ENG-7 as well
x = 1
")"
# A new file has no old text, so every line is added.
check "a Write creating a file carrying a key is reported" context \
  "$(write "$work/brand-new.py" "# from ENG-8
x = 1
")"
# An Edit quotes context it does not change. Reindenting a block, or appending
# under a line kept for uniqueness, carries the untouched comment through both
# sides of the payload.
check "an Edit quoting an existing key as context is silent" silent \
  "$(edit "$work/a.py" "# legacy note, see PRE-1
x = 1" "# legacy note, see PRE-1
x = 2")"

# --- 5. the standards prefixes ---
# `[A-Z][A-Z0-9]*-\d+` is the mechanically detectable trigger the rule names,
# and on its own it reads an encoding name as a ticket. These are the strings
# that actually appear in comments.
for token in UTF-8 SHA-256 RFC-7231 ISO-8601 CVE-2021 AES-256 GPT-4 UTC-5; do
  check "a comment naming $token is silent" silent \
    "$(edit "$work/a.py" "x = 1" "# encoded as $token here
x = 1")"
done
# A one-letter prefix is a quarter or an axis far more often than a tracker.
check "a comment naming Q1-2026 is silent" silent \
  "$(edit "$work/a.py" "x = 1" "# shipped Q1-2026
x = 1")"

# --- 6. prose files are out of scope ---
# A decision record, a README or a changelog cites a key as a matter of course,
# and markdown gives every heading a bare `#`.
check "a markdown file is silent" silent \
  "$(edit "$work/notes.md" "x" "# PRE-999 and the reasoning behind it")"
check "a markdown comment carrying a key is silent" silent \
  "$(edit "$work/notes.md" "x" "<!-- tracked as PRE-999 -->")"

# --- 7. the finding names the line it found ---
# A pointer that does not say which line it is about sends the reader back
# through the whole file.
check "the finding quotes the key" ok \
  "$(PY_PATH="$work/a.py" python3 -c '
import json, os
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "old_string": "x = 1",
        "new_string": "# see PRE-999\nx = 1",
    },
}))
' | bash "$hook" 2>/dev/null | grep -q 'PRE-999' && echo ok || echo missing)"

check "the finding names the remedy" ok \
  "$(PY_PATH="$work/a.py" python3 -c '
import json, os
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "old_string": "x = 1",
        "new_string": "# see PRE-999\nx = 1",
    },
}))
' | bash "$hook" 2>/dev/null | grep -q 'Delete the key and keep the sentence' && echo ok || echo missing)"

# --- 8. it advises and never denies ---
# The write that REMOVES a key must not be blocked alongside the one that adds
# it, and a bug here must cost a pointer rather than a session that cannot
# write files. `decisions/2026-09-16-dev-docs-hook-never-denies-the-write.md`.
check "the finding carries no permission decision" ok \
  "$(PY_PATH="$work/a.py" python3 -c '
import json, os
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "old_string": "x = 1",
        "new_string": "# see PRE-999\nx = 1",
    },
}))
' | bash "$hook" 2>/dev/null | python3 -c '
import json, sys
out = (json.load(sys.stdin).get("hookSpecificOutput") or {})
extra = set(out) - {"hookEventName", "additionalContext"}
print("ok" if not extra else "carries " + repr(sorted(extra)))
' 2>/dev/null)"

check "the finding carries hookEventName PreToolUse" ok \
  "$(PY_PATH="$work/a.py" python3 -c '
import json, os
print(json.dumps({
    "tool_name": "Edit",
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "old_string": "x = 1",
        "new_string": "# see PRE-999\nx = 1",
    },
}))
' | bash "$hook" 2>/dev/null | python3 -c '
import json, sys
out = (json.load(sys.stdin).get("hookSpecificOutput") or {})
print("ok" if out.get("hookEventName") == "PreToolUse" else repr(out.get("hookEventName")))
' 2>/dev/null)"

# --- 9. a payload it cannot read never blocks the tool call ---
printf 'not json at all' | bash "$hook" > "$work/bad" 2>/dev/null
check "a malformed payload exits 0" 0 "$?"
check "a malformed payload prints nothing" "" "$(cat "$work/bad")"

printf 'null' | bash "$hook" > "$work/null" 2>/dev/null
check "a null payload exits 0" 0 "$?"

check "a payload with no file_path is silent" silent \
  "$(printf '{"tool_name":"Edit","tool_input":{}}' | verdict)"

# A tool this hook has no added-text rule for is not scanned. Guessing one is
# how a NotebookEdit payload would be read as a whole-file write.
check "a tool other than Write or Edit is silent" silent \
  "$(printf '{"tool_name":"NotebookEdit","tool_input":{"file_path":"/r/a.py","new_source":"# PRE-9"}}' | verdict)"

# --- 10. the hook is registered on the tools that carry added text ---
# The script can be perfect and never run.
#
# It carries no `if`, unlike the dev_docs handlers under the same matcher.
# There is no path to narrow to -- the trigger is every source file -- and `if`
# expresses no negative glob, so the selectivity is the `case` pre-filter in
# the shell. The suite pins the absence so a later edit does not add an `if`
# that silently narrows this to one directory.
check "hooks.json registers the hook on Write and Edit, unconditionally" ok \
  "$(DIR="$self" python3 -c '
import json, os
with open(os.path.join(os.environ["DIR"], "hooks", "hooks.json")) as f:
    cfg = json.load(f)
entries = (cfg.get("hooks") or {}).get("PreToolUse") or []
problems = []
handlers = []
for e in entries:
    for h in e.get("hooks") or []:
        if "comment-key-context.sh" in h.get("command", ""):
            handlers.append(h)
            m = e.get("matcher", "")
            for tool in ("Write", "Edit"):
                if tool not in m:
                    problems.append("matcher %r does not cover %s" % (m, tool))
if not handlers:
    problems.append("no PreToolUse entry runs comment-key-context.sh")
for h in handlers:
    if h.get("if"):
        problems.append("handler carries if=%r, which narrows it to one path" % h["if"])
print("; ".join(problems) if problems else "ok")
' 2>/dev/null)"

# --- 11. the hook script is executable ---
# hooks.json invokes it by path. Without the bit it is "permission denied" at
# every write, which the harness reports as a hook failure.
check "the hook script is executable" ok \
  "$([ -x "$hook" ] && echo ok || echo "not executable")"

exit "$fail"
