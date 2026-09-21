#!/usr/bin/env bash
# Tests the plugin's PLUMBING: that the SessionStart hook is registered, that
# running it emits the documented JSON contract, that both payload files reach
# the context in a fixed order, and that the manifests which decide whether the
# plugin loads at all are wired up.
# Run: bash inject.test.sh
#
# Scope. This suite owns the wiring, not the content. It never asserts what
# the payload files say, only that what they say arrives intact.
#
# GUIDANCE_PLUGIN_DIR points the plugin-local assertions at a copy of the
# plugin directory, which is how inject-selftest.test.sh proves each assertion
# actually fails when its wiring is broken. inject.sh resolves its two markdown
# files relative to its own location, so only a whole-directory copy works.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${GUIDANCE_PLUGIN_DIR:-$self}"
fail=0

# A `python3 - <<'PY'` reads its SCRIPT from stdin, so it cannot also read piped
# data: the heredoc wins and sys.stdin is already exhausted. json.load then
# raises, 2>/dev/null swallows it, and the assertion compares against an empty
# string — a real failure that reads as a broken expectation. Every heredoc
# below therefore takes its payload from the environment, not from a pipe.
check() {
  local desc=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    printf 'ok   %s\n' "$desc"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$desc" "$want" "$got"
    fail=1
  fi
}

# --- 1. registration ---
# Running the script proves what the script emits; it proves nothing about what
# invokes it. Those fail independently, so they are asserted independently.
# Exact strings, not a suffix match: a registration pointing at a wrong subpath
# or an unquoted root would otherwise pass while nothing ever runs.
check "hooks.json registers inject.sh on SessionStart" ok \
  "$(DIR="$dir" python3 - <<'PY'
import json, os
# .get rather than [], so a hooks.json with the registration removed is judged
# ("no SessionStart entry") instead of raising. The selftest treats a traceback
# as a crash rather than a verdict, and it is right to: a suite that dies on the
# mutation it exists to catch reports which file it was reading, not what was
# wrong with it.
hooks = json.load(open(os.path.join(os.environ["DIR"], "hooks/hooks.json")))["hooks"]
h = hooks.get("SessionStart")
if h is None:
    print("no SessionStart entry in hooks/hooks.json")
else:
    cmds = [c["command"] for m in h for c in m["hooks"]]
    print("ok" if '"${CLAUDE_PLUGIN_ROOT}"/inject.sh' in cmds else cmds)
PY
)"

# The Codex registration must hand inject.sh portable.md ALONE: with no argument
# the script defaults to both files, and portable-claude.md names machinery
# Codex does not have.
check "codex/hooks.json registers inject.sh with portable.md only" ok \
  "$(DIR="$dir" python3 - <<'PY'
import json, os
hooks = json.load(open(os.path.join(os.environ["DIR"], "codex/hooks.json")))["hooks"]
h = hooks.get("SessionStart")
want = '"${PLUGIN_ROOT}"/inject.sh "${PLUGIN_ROOT}"/portable.md'
if h is None:
    print("no SessionStart entry in codex/hooks.json")
else:
    cmds = [c["command"] for c in h]
    print("ok" if cmds == [want] else cmds)
PY
)"

check "root plugin.json points Codex at codex/hooks.json" ./codex/hooks.json \
  "$(DIR="$dir" python3 -c 'import json,os; print(json.load(open(os.path.join(os.environ["DIR"], "plugin.json")))["extensions"]["com.openai"]["hooks"])')"

# --- 2. the hook runs and emits the documented contract ---
out=$(printf '{"session_id":"t","cwd":"/tmp","hook_event_name":"SessionStart"}' \
  | "$dir/inject.sh" 2>/dev/null)
rc=$?
check "hook exits 0" 0 "$rc"

check "stdout is valid JSON" ok \
  "$(printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin); print("ok")')"

check "hookEventName is SessionStart" SessionStart \
  "$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["hookEventName"])')"

# --- 3. both files reach the payload, in a fixed order ---
# One file silently dropped is the exact loss the plugin exists to prevent, and
# the order is fixed so that a diff of two sessions' context is a diff of the
# files rather than of the hook.
check "additionalContext carries both sentinels in file order" ok \
  "$(OUT="$out" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
shared = ctx.find("GUIDANCE-SENTINEL-SHARED")
claude = ctx.find("GUIDANCE-SENTINEL-CLAUDE")
if shared < 0:
    print("shared sentinel missing")
elif claude < 0:
    print("claude sentinel missing")
elif shared > claude:
    print("wrong order: portable-claude.md precedes portable.md")
else:
    print("ok")
PY
)"

# --- 3b. a caller that names one file gets that file alone ---
# This is the Codex path. The shared sentinel must arrive and the Claude one
# must not; a hook that ignored its arguments would pass every check above.
shared_out=$(printf '{"hook_event_name":"SessionStart"}' | "$dir/inject.sh" "$dir/portable.md" 2>/dev/null)
check "inject.sh portable.md emits the shared sentinel only" ok \
  "$(OUT="$shared_out" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
if "GUIDANCE-SENTINEL-SHARED" not in ctx:
    print("shared sentinel missing")
elif "GUIDANCE-SENTINEL-CLAUDE" in ctx:
    print("claude sentinel leaked")
else:
    print("ok")
PY
)"

# --- 4. JSON validity against an adversarial payload ---
# The hook builds its JSON in Python precisely because hand-quoted JSON mangles
# backticks, quotes and backslashes silently — the result stays parseable, so
# the damage reads as garbled guidance rather than an error. Assert the decoded
# text is byte-identical to the fixture, which is what catches the mangling.
work="$(make_workdir guidance-inject)"
trap 'rm -rf "$work"' EXIT
cp "$dir/inject.sh" "$work/inject.sh"
python3 - "$work" <<'PY'
import os, sys

work = sys.argv[1]
hostile = (
    "# Adversarial fixture\n"
    "\n"
    "A backtick span: `printf '%s\\n' \"$VAR\"` and a bare $VAR.\n"
    "Double \"quotes\", single 'quotes', a backslash \\ and a pair \\\\.\n"
    "---\n"
    "Tab\there, and a brace } plus a bracket ].\n"
)
with open(os.path.join(work, "portable.md"), "w") as f:
    f.write(hostile)
with open(os.path.join(work, "portable-claude.md"), "w") as f:
    f.write(hostile.replace("Adversarial fixture", "Adversarial fixture, second half"))
PY

hostile_out=$(printf '{"hook_event_name":"SessionStart"}' | "$work/inject.sh" 2>/dev/null)
check "adversarial payload is still valid JSON" ok \
  "$(printf '%s' "$hostile_out" | python3 -c 'import json,sys; json.load(sys.stdin); print("ok")')"

# The payload is the whole context MINUS the provenance block the hook appends.
# Splitting on that block rather than dropping the assertion keeps the mangling
# check exact: everything before the marker must still be byte-identical to the
# files, so a backslash or backtick eaten anywhere in the payload still fails.
check "adversarial payload round-trips byte-for-byte" ok \
  "$(OUT="$hostile_out" WORK="$work" python3 - <<'PY'
import json, os
got = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
parts = []
for name in ("portable.md", "portable-claude.md"):
    with open(os.path.join(os.environ["WORK"], name)) as f:
        parts.append(f.read().rstrip("\n"))
head, sep, _ = got.partition("\n\n## Provenance of this guidance\n")
if not sep:
    print("provenance block missing")
elif head != "\n\n".join(parts):
    print(f"payload differs: {head!r}")
else:
    print("ok")
PY
)"

# --- 4b. the provenance block: what this copy is, so a session can say ---
# An installed plugin does not follow a merge and nothing in a session can tell.
# These assert the shapes the copy comes in, because each is a separate branch
# and the wrong branch is silent — a stale copy reporting itself confidently as
# current is worse than no line at all.

# A marketplace install lands in a directory named for the short commit sha,
# because plugin.json declares no version. That is the shape that ships.
sha_root="$work/87e76fd2bf12"
mkdir -p "$sha_root"
cp "$dir/inject.sh" "$sha_root/inject.sh"
printf 'payload\n' > "$sha_root/portable.md"
printf 'payload two\n' > "$sha_root/portable-claude.md"
# The payload file is backdated while its directory stays at now: the date must
# come from the file, never the directory, which an `.in_use` marker bumps on
# every use. A regression to the directory mtime reports today and fails here.
touch -t 202001010000 "$sha_root/portable.md"
sha_out=$(printf '{"hook_event_name":"SessionStart"}' | "$sha_root/inject.sh" 2>/dev/null)
check "an installed copy reports its commit" ok \
  "$(OUT="$sha_out" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
if "commit `87e76fd2bf12`" not in ctx:
    print(f"commit not named: {ctx[-400:]!r}")
elif "written 2020-01-01" not in ctx:
    print(f"date is not the payload file's: {ctx[-400:]!r}")
elif "claude plugin update agent-guidance@agent-guidance" not in ctx:
    print("no refresh instruction")
else:
    print("ok")
PY
)"

# A `--plugin-dir` checkout is unreleased code, and saying "commit <dirname>"
# there would name a directory, not a commit — confidently wrong. A checkout
# comes in two shapes: a main checkout, whose `.git` is a directory, and a
# linked worktree, whose `.git` is a file holding `gitdir: …`. Both must read as
# a checkout; an isdir test passed the first and offered the second a refresh.
for shape in directory file; do
  git_root="$work/checkout-$shape/agent-guidance"
  mkdir -p "$git_root"
  if [ "$shape" = directory ]; then
    mkdir "$git_root/.git"
  else
    printf 'gitdir: /elsewhere/.git/worktrees/agent-guidance\n' > "$git_root/.git"
  fi
  cp "$dir/inject.sh" "$git_root/inject.sh"
  printf 'payload\n' > "$git_root/portable.md"
  printf 'payload two\n' > "$git_root/portable-claude.md"
  git_out=$(printf '{"hook_event_name":"SessionStart"}' | "$git_root/inject.sh" 2>/dev/null)
  check "a working checkout (.git $shape) says so instead of naming a commit" ok \
    "$(OUT="$git_out" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
if "working checkout" not in ctx:
    print(f"not reported as a checkout: {ctx[-400:]!r}")
# chr(96) rather than a literal backtick: an unbalanced one inside this $( … )
# starts a legacy command substitution and the whole file stops parsing.
elif "commit " + chr(96) in ctx:
    print("named a commit for a checkout")
elif "claude plugin update" in ctx:
    print("offered a refresh that would discard the checkout")
else:
    print("ok")
PY
  )"
done

# The Codex registration passes one file. The provenance has to survive that
# path too — it is the path on which a stale copy is hardest to notice, because
# the generated ~/.codex/AGENTS.md looks the same however old it is.
check "the single-file (Codex) path still carries provenance" ok \
  "$(OUT="$shared_out" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
print("ok" if "## Provenance of this guidance" in ctx else "provenance missing")
PY
)"

# The provenance must also name the directory it delivered from. Two rules in
# portable.md tell a harness with no skills to read three files by filename
# alone, and nothing else in the payload resolves that directory. A path merely
# being present is not enough — it has to be the copy that ran — so the
# assertion compares it against the directory under test.
check "the provenance names the plugin root it delivered from" ok \
  "$(DIR="$dir" OUT="$shared_out" python3 - <<'PY'
import json, os
ctx = json.loads(os.environ["OUT"])["hookSpecificOutput"]["additionalContext"]
want = "The plugin root is " + chr(96) + os.environ["DIR"] + chr(96)
print("ok" if want in ctx else f"root not named: {ctx[-400:]!r}")
PY
)"

# --- 5. the two payload files are disjoint ---
# Both are injected into the same session, so anything in both is delivered
# twice. The sentinels are the coarse form of the same check: each marks its
# own file, so a marker appearing in the other means the halves were merged.
#
# Headings are excluded because they are structure, not content. Both files
# group their rules under the same section names as agents/AGENTS.md, so
# `## Rules` is in both by construction and says nothing about whether a rule
# is. Every other line still has to be unique across the pair.
check "no line appears in both payload files" "" \
  "$(DIR="$dir" python3 - <<'PY'
import os

def lines(path):
    with open(path) as f:
        return {l.strip() for l in f if l.strip() and not l.startswith("#")}

d = os.environ["DIR"]
both = lines(os.path.join(d, "portable.md")) & lines(os.path.join(d, "portable-claude.md"))
print("\n".join(sorted(b[:60] for b in both)))
PY
)"

for pair in "portable.md:GUIDANCE-SENTINEL-CLAUDE" "portable-claude.md:GUIDANCE-SENTINEL-SHARED"; do
  file="${pair%%:*}"
  marker="${pair##*:}"
  got=absent
  grep -qF "$marker" "$dir/$file" && got=present
  check "$file does not carry $marker" absent "$got"
done

# --- 6. manifests: the plugin has to be installable before any of it matters ---
# No version anywhere. A pinned version in either manifest makes the marketplace
# resolve a release rather than this checkout, so an edit here would ship
# nothing until someone remembered to bump it.
check ".claude-plugin/plugin.json parses and names the plugin" agent-guidance \
  "$(DIR="$dir" python3 -c 'import json,os; print(json.load(open(os.path.join(os.environ["DIR"], ".claude-plugin/plugin.json")))["name"])')"

check ".claude-plugin/plugin.json declares no version" absent \
  "$(DIR="$dir" python3 -c 'import json,os; print("present" if "version" in json.load(open(os.path.join(os.environ["DIR"], ".claude-plugin/plugin.json"))) else "absent")')"

# The marketplace entry is what `enabledPlugins` resolves through; a wrong
# relative source installs an empty plugin that fails silently. The plugin is
# the repo root, so the source is "./".
check "marketplace lists the plugin at the repo root, unversioned" ok \
  "$(DIR="$dir" python3 - <<'PY'
import json, os
root = os.environ["DIR"]
m = json.load(open(os.path.join(root, ".claude-plugin/marketplace.json")))
entry = next((p for p in m["plugins"] if p["name"] == "agent-guidance"), None)
if entry is None:
    print("no guidance entry")
elif entry.get("source") != "./":
    print(f"bad source: {entry.get('source')!r}")
elif "version" in entry:
    print("entry declares a version")
else:
    print("ok")
PY
)"

exit "$fail"
