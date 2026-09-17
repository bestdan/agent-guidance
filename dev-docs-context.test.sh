#!/usr/bin/env bash
# Tests hooks/dev-docs-context.sh, the PreToolUse hook that names the layout
# before a session writes under dev_docs/.
# Run: bash dev-docs-context.test.sh
#
# Why this suite exists. The hook's whole value is that it fires without anyone
# deciding it should, which is also why nothing reports it when it stops firing:
# a session that never gets the pointer looks exactly like a session that did
# not need one. That is the same silent-loss shape inject.test.sh guards for the
# payload, and it needs the same treatment.
#
# The cases are the boundaries, not the happy path. A substring match on
# "dev_docs" and a per-write rather than per-session pointer are the two ways
# this hook goes wrong while still appearing to work.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook="$self/hooks/dev-docs-context.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/dev-docs-context-test.XXXXXX")"
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

# Feeds the hook one payload and echoes "context" when it emitted a pointer,
# "silent" when it emitted nothing, or "notjson" when what it printed is not
# parseable. Session and scratchpad are parameters because the once-per-session
# marker is keyed on both, and a case that reused either would pass on the
# strength of a previous case's marker.
#
# `local` is split across lines because bash 3.2, which is what macOS ships,
# does not see an earlier name on the same `local` line under `set -u`.
emit() {
  local path=$1
  local session=$2
  local scratch=$3
  printf '{"hook_event_name":"PreToolUse","tool_name":"Write","session_id":"%s","scratchpad_dir":"%s","tool_input":{"file_path":"%s"}}' \
    "$session" "$scratch" "$path" \
    | bash "$hook" > "$work/out" 2>/dev/null
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

# --- 1. a file under dev_docs/ gets the pointer ---
check "a file under dev_docs/ gets the pointer" context \
  "$(emit /repo/dev_docs/designs/2026-09-16-thing.md s1 "$work/s1")"

# --- 2. a file outside dev_docs/ does not ---
# The cost of a false positive is a paragraph in front of every source edit in
# every repo on the machine, so this boundary matters more than case 1.
check "a file outside dev_docs/ is silent" silent \
  "$(emit /repo/src/parser.py s2 "$work/s2")"

# --- 3. dev_docs_layout.md at a repo root is not a file under dev_docs/ ---
# A substring test passes case 1 and case 2 and still fires here, on the one
# file whose author is editing the convention itself.
check "dev_docs_layout.md at a root is silent" silent \
  "$(emit /repo/dev_docs_layout.md s3 "$work/s3")"

# --- 4. the directory itself is not a file under it ---
check "a path ending at dev_docs is silent" silent \
  "$(emit /repo/dev_docs s4 "$work/s4")"

# --- 5. once per session, not once per write ---
# A plan that writes nine records would otherwise pay for nine copies.
check "the first write in a session gets the pointer" context \
  "$(emit /repo/dev_docs/a.md s5 "$work/s5")"
check "the second write in the same session is silent" silent \
  "$(emit /repo/dev_docs/b.md s5 "$work/s5")"

# --- 6. a different session gets its own pointer ---
# The marker is keyed on the session id rather than the repo, so a second
# session in the same checkout is not starved by the first.
check "a different session gets the pointer again" context \
  "$(emit /repo/dev_docs/c.md s6 "$work/s6")"

# --- 7. a malformed payload never blocks the write ---
# A PreToolUse hook that exits nonzero blocks the tool call. Failing a
# session's write because this script could not parse its own input would be
# worse than any pointer is worth, so the exit status is asserted directly.
printf 'not json at all' | bash "$hook" > "$work/bad" 2>/dev/null
check "a malformed payload exits 0" 0 "$?"
check "a malformed payload prints nothing" "" "$(cat "$work/bad")"

printf 'null' | bash "$hook" > "$work/null" 2>/dev/null
check "a null payload exits 0" 0 "$?"

check "a payload with no file_path is silent" silent \
  "$(printf '{"tool_input":{}}' | bash "$hook" 2>/dev/null | grep -q additionalContext && echo context || echo silent)"

# --- 8. the emitted JSON is the shape the harness reads ---
# additionalContext alone is not enough: the harness dispatches on
# hookEventName, and a pointer under the wrong event name is dropped silently.
check "the pointer carries hookEventName PreToolUse" ok \
  "$(printf '{"session_id":"s8","scratchpad_dir":"%s","tool_input":{"file_path":"/r/dev_docs/x.md"}}' "$work/s8" \
    | bash "$hook" 2>/dev/null \
    | python3 -c '
import json, sys
body = json.load(sys.stdin)
out = body.get("hookSpecificOutput") or {}
print("ok" if out.get("hookEventName") == "PreToolUse" else repr(out.get("hookEventName")))
' 2>/dev/null)"

# --- 9. the pointer names the files it exists to name ---
# The only content assertions in this suite. A pointer that does not name
# dev_docs_layout.md is a paragraph of prose with nothing to follow.
check "the pointer names dev_docs_layout.md" ok \
  "$(printf '{"session_id":"s9","scratchpad_dir":"%s","tool_input":{"file_path":"/r/dev_docs/x.md"}}' "$work/s9" \
    | bash "$hook" 2>/dev/null \
    | grep -q 'dev_docs_layout.md' && echo ok || echo missing)"

# The repo's own dev_docs/README.md carries that repo's exceptions, and the
# pointer says those exceptions win. It said so once while telling the reader to
# open only the layout and the immediate directory README -- naming a file as
# authoritative and then leaving it out of the reading.
#
# Matching the file name alone would NOT catch that: the broken version named
# dev_docs/README.md too, in the sentence about precedence. What has to be
# pinned is the file's place in the READ SEQUENCE, so the phrase is matched
# rather than the name.
check "the pointer reads the repo dev_docs/README.md in sequence" ok \
  "$(printf '{"session_id":"s9b","scratchpad_dir":"%s","tool_input":{"file_path":"/r/dev_docs/designs/x.md"}}' "$work/s9b" \
    | bash "$hook" 2>/dev/null \
    | grep -q 'then the dev_docs/README.md at the repo root, then the README.md of the directory' \
    && echo ok || echo missing)"

# --- 10. the hook is registered, on the events that carry a file_path ---
# The script can be perfect and never run. hooks.json is the wiring, and a
# matcher that lost Write or Edit is the failure this catches.
check "hooks.json registers the hook on Write and Edit" ok \
  "$(DIR="$self" python3 -c '
import json, os
with open(os.path.join(os.environ["DIR"], "hooks", "hooks.json")) as f:
    cfg = json.load(f)
entries = (cfg.get("hooks") or {}).get("PreToolUse") or []
problems = []
matched = [e for e in entries
           if any("dev-docs-context.sh" in h.get("command", "")
                  for h in (e.get("hooks") or []))]
if not matched:
    problems.append("no PreToolUse entry runs dev-docs-context.sh")
for e in matched:
    m = e.get("matcher", "")
    for tool in ("Write", "Edit"):
        if tool not in m:
            problems.append("matcher %r does not cover %s" % (m, tool))
print("; ".join(problems) if problems else "ok")
' 2>/dev/null)"

# --- 11. the hook script is executable ---
# hooks.json invokes it by path. A file without the bit is "permission denied"
# at every write, which the harness reports as a hook failure rather than as a
# missing pointer.
check "the hook script is executable" ok \
  "$([ -x "$hook" ] && echo ok || echo "not executable")"

exit "$fail"
