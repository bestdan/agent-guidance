#!/usr/bin/env bash
# Tests hooks/prose-context.sh, the PreToolUse hook that reports a tracker key
# added in a code comment and, on markdown, insider prose.
# Run: bash prose-context.test.sh
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
hook="$self/hooks/prose-context.sh"
work="$(make_workdir prose-context-test)"
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

# Every payload carries a session and a scratchpad, because a markdown write
# leaves a once-per-session marker there. Without them the marker lands in the
# hook's fallback directory, shared with every other run on the machine, and a
# case would pass or fail on what an earlier run left behind. SESSION defaults
# to one id; a case that needs a fresh pointer sets its own.
SESSION=keys
scratch="$work/scratch"

# An Edit payload: the file path, the replaced text, the replacing text.
edit() {
  PY_PATH=$1 PY_OLD=$2 PY_NEW=$3 PY_SESSION=$SESSION PY_SCRATCH=$scratch python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "tool_name": "Edit",
    "session_id": os.environ["PY_SESSION"],
    "scratchpad_dir": os.environ["PY_SCRATCH"],
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
  PY_PATH=$1 PY_NEW=$2 PY_SESSION=$SESSION PY_SCRATCH=$scratch python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "tool_name": "Write",
    "session_id": os.environ["PY_SESSION"],
    "scratchpad_dir": os.environ["PY_SCRATCH"],
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
# The two markers with a carve-out of their own: `--` is taken only with a
# space after it, and `*` only as the first thing on the line. Both are live
# paths in comment_at(), and neither was exercised by the cases around them.
check "an added -- comment carrying a key is reported" context \
  "$(edit "$work/a.sql" "select 1;" "-- PRE-4 wanted this column
select 1;")"
check "an added javadoc continuation carrying a key is reported" context \
  "$(edit "$work/A.java" "int x = 1;" " * PRE-5 asked for the cast
int x = 1;")"
# The carve-out itself: a --flag is not a comment marker.
check "a --flag in a shell line is silent" silent \
  "$(edit "$work/a.sh" "x=1" 'run --project PRE-6 --now')"

# --- 2. TODO is the exception the rule names ---
# There the key names outstanding work rather than citing a source, so a guard
# that fired here would be enforcing more than portable.md says.
check "a TODO carrying a key is silent" silent \
  "$(edit "$work/a.py" "x = 1" "# TODO(PRE-999): drop this once the migration lands
x = 1")"
# The bare spelling is the same exception. portable.md writes the exception as
# `TODO(PRE-999):`, but its reason -- the key names outstanding work rather
# than citing a source -- holds for this one too, and a guard that reported it
# would be firing on a comment the rule tolerates.
check "a bare TODO carrying a key is silent" silent \
  "$(edit "$work/a.py" "x = 1" "# TODO: fix per PRE-999
x = 1")"
# The exemption counts only inside the comment. A TODO in the code says
# nothing about the comment beside it, and testing the whole line let a string
# exempt a real violation.
check "a TODO in code does not exempt the comment" context \
  "$(edit "$work/a.py" "x = 1" 'x = "TODO"  # per PRE-999')"

# --- 3. code is not a comment ---
# A key in a string, a variable or a branch name is not the thing the rule is
# about, and a scan that did not find the comment marker first would report all
# three.
check "a key in a string literal is silent" silent \
  "$(edit "$work/a.py" "x = 1" 'ticket = "PRE-999"')"
check "a key in a URL in code is silent" silent \
  "$(edit "$work/a.py" "x = 1" 'url = "https://example.com/ABC-123"')"
# A URL fragment's # is not a comment marker: it has a non-space before it.
check "a key in a URL fragment is silent" silent \
  "$(edit "$work/a.py" "x = 1" 'url = "https://example.com/x/#ABC-123"')"
# But the scan walks past that # rather than stopping at it, so a real comment
# later on the same line is still found. A one-shot find() fails this case.
check "a comment after a # literal is still read" context \
  "$(edit "$work/a.css" "a { color: red; }" 'color = "#FFF";  # per PRE-999')"

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

# --- 6. prose files are out of scope for the key check ---
# A decision record, a README or a changelog cites a key as a matter of course,
# and markdown gives every heading a bare `#`. Markdown is not silent any more
# -- it gets the insider-prose pointer, section 14 -- so the first write below
# spends this session's pointer, and the two after it pin the key check alone.
check "the session's first markdown write gets the pointer" context \
  "$(edit "$work/notes.md" "x" "y")"
check "a markdown file is silent" silent \
  "$(edit "$work/notes.md" "x" "# PRE-999 and the reasoning behind it")"
check "a markdown comment carrying a key is silent" silent \
  "$(edit "$work/notes.md" "x" "<!-- tracked as PRE-999 -->")"
check "a plain-text file is silent" silent \
  "$(edit "$work/notes.txt" "x" "# PRE-999 and the reasoning behind it")"

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
')"

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
')"

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
        if "prose-context.sh" in h.get("command", ""):
            handlers.append(h)
            m = e.get("matcher", "")
            for tool in ("Write", "Edit"):
                if tool not in m:
                    problems.append("matcher %r does not cover %s" % (m, tool))
if not handlers:
    problems.append("no PreToolUse entry runs prose-context.sh")
for h in handlers:
    if h.get("if"):
        problems.append("handler carries if=%r, which narrows it to one path" % h["if"])
print("; ".join(problems) if problems else "ok")
')"

# --- 11. the program sits beside the wrapper and parses ---
# The wrapper runs prose-context.py by path with its stderr discarded, so a
# file that is missing, unreadable, or a syntax error is a hook that says
# nothing on every payload and reports nothing. That is the same silent shape an
# apostrophe inside the old `python3 -c` argument produced, which is the case
# this one replaces: a `.py` file has no enclosing quote to end, so the
# apostrophe hazard is gone, while the never-block rule keeps the other
# failures quiet at runtime. This says which file and which line.
check "the program sits beside the wrapper and parses" ok \
  "$(PROG="$self/hooks/prose-context.py" python3 -c '
import os
p = os.environ["PROG"]
try:
    src = open(p).read()
except OSError as e:
    print("cannot read %s: %s" % (p, e))
else:
    try:
        compile(src, p, "exec")
    except SyntaxError as e:
        print("%s:%s: %s" % (p, e.lineno, e.msg))
    else:
        print("ok")
')"

# --- 12. the hook script is executable ---
# hooks.json invokes it by path. Without the bit it is "permission denied" at
# every write, which the harness reports as a hook failure.
check "the hook script is executable" ok \
  "$([ -x "$hook" ] && echo ok || echo "not executable")"

# --- 13. a wrapper whose program is gone still exits 0 and says nothing ---
# The new failure mode, and the only measurement holding up the never-block
# claim for it. The wrapper runs its program by path with stderr discarded and
# exits 0 unconditionally, so a missing or unparsable `.py` file is silent --
# which is the cost the extraction accepts, not an accident. A wrapper that
# propagated the program's exit status instead would report a finding as a blocked write.
# The copy carries the wrapper alone, so `$here` holds no program to find.
lone="$work/lone"
mkdir -p "$lone"
cp "$hook" "$lone/prose-context.sh"
# The payload has to clear the prefilter, or python is never reached and the
# case would pass on a wrapper that had no program to run in the first place.
lone_out="$(printf %s '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/nonexistent/x.py","content":"# added because PRE-999 asked for it"}}' | bash "$lone/prose-context.sh" 2>/dev/null)"
lone_code=$?
check "a wrapper with no program exits 0" 0 "$lone_code"
check "a wrapper with no program says nothing" "" "$lone_out"

# --- 14. markdown: the insider-prose pointer and the dangling-reference check ---
# The pointer is the half that matters: it fires without the model choosing to
# re-read anything. The detector is one report-only regex riding the same
# process.

# Prints the additionalContext the hook emitted for the payload on stdin, or
# nothing. The cases below assert on content, not only on presence, because a
# pointer quoting the wrong text or a miss message is still "context".
context_of() {
  bash "$hook" 2>/dev/null | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if raw:
    print((json.loads(raw).get("hookSpecificOutput") or {}).get("additionalContext", ""))
'
}

# A markdown Edit payload under a given session, printed rather than run, so a
# case can pipe it into context_of with whatever environment it needs.
md_payload() {
  PY_SESSION=$1 PY_PATH=$2 PY_OLD=$3 PY_NEW=$4 PY_SCRATCH=$scratch python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "tool_name": "Edit",
    "session_id": os.environ["PY_SESSION"],
    "scratchpad_dir": os.environ["PY_SCRATCH"],
    "tool_input": {
        "file_path": os.environ["PY_PATH"],
        "old_string": os.environ["PY_OLD"],
        "new_string": os.environ["PY_NEW"],
    },
}))
'
}

has() {
  case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac
}

# The pointer quotes the repo's own section, end to end: the wrapper's
# GUIDANCE_ROOT, the heading lookup, and the section boundary. This is the
# assertion that the rule the hook points at still resolves. A renamed heading
# fails it here rather than in every installed session.
out="$(md_payload md1 "$work/a.md" x "plain prose" | context_of)"
check "the first markdown write quotes the rule's heading" yes \
  "$(has "$out" "## Don't write insider prose")"
check "the quote carries the section's body" yes \
  "$(has "$out" "Leave no reference dangling")"
# Matched as a line start: the section cites `## Say what you know` inline.
check "the quote stops at the next section" no \
  "$(has "$out" $'\n## Say what you know')"
check "the quote names the file it came from" yes \
  "$(has "$out" "/writing_about_code.md")"
check "the second clean markdown write in the session is silent" "" \
  "$(md_payload md1 "$work/a.md" x "more plain prose" | context_of)"

# A sentence-start capital is the case a glob prefilter written for the
# detector's shape would miss. The payload carries no tracker-key shape, so
# only the markdown arm of the prefilter admits it.
out="$(md_payload md1 /nonexistent/notes.md x "The same 14 rows scored well." | context_of)"
check "a dangling-reference shape is reported" yes "$(has "$out" "The same 14 rows")"
check "the finding names its line" yes "$(has "$out" "line 1 of the edit")"
check "the finding does not repeat the pointer" no "$(has "$out" "Leave no reference")"

out="$(md_payload md1 /nonexistent/notes.md x "intro

and the same 3 files again" | context_of)"
check "a finding's line is its line in the new text" yes "$(has "$out" "line 3 of")"

# Upper-case extensions: the prefilter is a glob, so the case fold is its own.
check "an .MD extension is admitted" yes \
  "$(has "$(md_payload md1 /nonexistent/NOTES.MD x "the same 2 paths" | context_of)" "the same 2 paths")"

# Stripped before scanning: a backticked example is how markdown quotes a
# string, and a single-line HTML comment is not prose.
check "a backticked example is silent" "" \
  "$(md_payload md1 /nonexistent/n.md x 'writes like `the same 14 rows` dangle' | context_of)"
check "a single-line HTML comment is silent" "" \
  "$(md_payload md1 /nonexistent/n.md x '<!-- the same 14 rows -->' | context_of)"

# Added lines only, for the same reason as the key check: a sentence that
# pre-dates the rule is not this write's finding.
printf 'The same 14 rows.\n' > "$work/old.md"
check "a Write keeping an existing shape is silent" "" \
  "$(PY_PATH="$work/old.md" PY_SCRATCH=$scratch python3 -c '
import json, os
print(json.dumps({"tool_name": "Write", "session_id": "md1",
    "scratchpad_dir": os.environ["PY_SCRATCH"],
    "tool_input": {"file_path": os.environ["PY_PATH"],
                   "content": "The same 14 rows.\nA new line.\n"}}))
' | context_of)"

# A plain-text file is prose, but not markdown: neither check reads it.
check "a .txt write is silent" "" \
  "$(md_payload md2 /nonexistent/n.txt x "The same 14 rows." | context_of)"

# Fails closed. A root whose writing_about_code.md lost the heading, carries it
# twice, or is missing entirely produces a message naming the miss rather than
# a silent session. Each case gets a fresh session, since the miss rides the
# once-per-session pointer.
fake="$work/fakeroot"
mkdir -p "$fake"
out="$(md_payload miss1 /nonexistent/n.md x "prose" | CLAUDE_PLUGIN_ROOT="$fake" context_of)"
check "a missing writing_about_code.md is reported" yes "$(has "$out" "could not quote")"
printf '# W\n\n## Something else\n\ntext\n' > "$fake/writing_about_code.md"
out="$(md_payload miss2 /nonexistent/n.md x "prose" | CLAUDE_PLUGIN_ROOT="$fake" context_of)"
check "a renamed heading is reported" yes "$(has "$out" "0 '## Don't write insider prose' headings")"
printf "## Don't write insider prose\n\na\n\n## Don't write insider prose\n\nb\n" > "$fake/writing_about_code.md"
out="$(md_payload miss3 /nonexistent/n.md x "prose" | CLAUDE_PLUGIN_ROOT="$fake" context_of)"
check "a duplicated heading is reported" yes "$(has "$out" "2 '## Don't write insider prose' headings")"
# The detector lives under the root too, and the fake root carries none. The
# hook says so rather than dropping the check silently.
check "a missing detector is reported" yes "$(has "$out" "insider_prose.py is missing")"

# The pointer and the finding still never carry a permission decision.
check "the markdown output carries no permission decision" ok \
  "$(md_payload md3 /nonexistent/n.md x "The same 14 rows." | bash "$hook" 2>/dev/null | python3 -c '
import json, sys
out = (json.load(sys.stdin).get("hookSpecificOutput") or {})
extra = set(out) - {"hookEventName", "additionalContext"}
print("ok" if not extra else "carries " + repr(sorted(extra)))
')"

exit "$fail"
