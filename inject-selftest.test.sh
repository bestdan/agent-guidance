#!/usr/bin/env bash
# Tests the tripwire itself: inject.test.sh is run against copies of the plugin
# directory with one piece of wiring broken in each, and its verdict compared to
# an expected one.
# Run: bash inject-selftest.test.sh
#
# Why this exists. inject.test.sh passing tells you the wiring is intact today.
# It does not tell you the suite would notice if the wiring broke — an
# assertion that reads the wrong file, or compares against an empty string it
# also produces on error, passes exactly the same way. A check nobody can
# regress is worth more than a check somebody ran once.
#
# Whole-directory copies, not single-file edits: inject.sh resolves its two
# markdown files relative to its own location, so GUIDANCE_PLUGIN_DIR only
# reaches the mutated copy when the copy holds every file the suite reads.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
suite="$dir/inject.test.sh"
fail=0
checked=0

# `cd … && pwd` rather than mktemp's output as given, because that output is
# compared against a path inject.sh computed for itself. macOS sets TMPDIR with
# a trailing slash, so the interpolation above yields `…/T//guidance-selftest.X`
# while inject.sh's own `cd … && pwd` collapses the `//` to `/`. The two paths
# then differ by one character and the provenance assertion fails on a hook that
# is working correctly. Normalizing here the same way inject.sh does is what
# makes the comparison compare directories rather than spellings.
#
# The Linux runner sets no TMPDIR, so the `/tmp` default has no trailing slash
# and CI never saw this --- it reproduced only on a developer's macOS machine,
# and only outside the Claude Code sandbox, whose TMPDIR also lacks the slash.
work="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/guidance-selftest.XXXXXX")" && pwd)"
trap 'rm -rf "$work"' EXIT

# A fresh, unmutated copy of the plugin under $work/<name>. The .git directory
# is left out: the copies are fixtures, not checkouts.
fixture() {
  local name=$1 target="$work/$1"
  rm -rf "$target"
  mkdir -p "$target"
  (cd "$dir" && tar --exclude=.git -cf - .) | (cd "$target" && tar -xf -)
  printf '%s' "$target"
}

# expect_fail <name> -- the suite must reject the mutated copy (non-zero exit)
# expect_pass <name> -- the suite must accept the copy (zero exit)
check() {
  local want=$1 name=$2 target=$3 out rc
  out="$(GUIDANCE_PLUGIN_DIR="$target" bash "$suite" 2>&1)"
  rc=$?
  checked=$((checked + 1))

  if printf '%s' "$out" | grep -q 'Traceback'; then
    printf 'FAIL %-32s crashed with a traceback\n' "$name"
    fail=1
    return
  fi

  case "$want" in
    fail)
      if [ "$rc" -eq 0 ]; then
        printf 'FAIL %-32s expected the suite to fail, it passed\n' "$name"
        fail=1
      fi
      ;;
    pass)
      if [ "$rc" -ne 0 ]; then
        printf 'FAIL %-32s expected the suite to pass, it failed:\n%s\n' "$name" "$out"
        fail=1
      fi
      ;;
  esac
}

# --- control: an unmutated copy passes ---
# Without this every row below could be satisfied by a suite that fails on any
# copy at all, which would prove nothing about the mutations.
check pass "unmutated copy" "$(fixture pristine)"

# --- (a) the registration is gone, the script still works ---
# This is the failure that running inject.sh can never catch: the script emits
# a perfect payload and nothing invokes it.
target="$(fixture no-registration)"
OUT="$target/hooks/hooks.json" python3 - <<'PY'
import json, os

path = os.environ["OUT"]
with open(path) as f:
    hooks = json.load(f)
del hooks["hooks"]["SessionStart"]
with open(path, "w") as f:
    json.dump(hooks, f, indent=2)
PY
check fail "SessionStart registration removed" "$target"

# --- (b) one file dropped from the payload ---
# portable-claude.md still exists and still parses; it simply stops being
# delivered, which is the silent half-loss the plugin exists to prevent.
target="$(fixture one-file)"
OUT="$target/inject.sh" python3 - <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
old = 'set -- "$here/portable.md" "$here/portable-claude.md"'
new = 'set -- "$here/portable.md"'
assert src.count(old) == 1, "inject.sh no longer defaults to both files on one line"
with open(path, "w") as f:
    f.write(src.replace(old, new))
PY
check fail "second file dropped from payload" "$target"

# --- (c) the two halves overlap ---
# Both files are injected into the same session, so a line in both is delivered
# twice. Copying the Claude sentinel into portable.md trips both halves of the
# disjointness check at once.
target="$(fixture merged-halves)"
OUT="$target/portable.md" python3 - <<'PY'
import os

path = os.environ["OUT"]
with open(path, "a") as f:
    f.write("\nMarker for the delivery tests: `GUIDANCE-SENTINEL-CLAUDE`.\n")
PY
check fail "claude sentinel copied into portable.md" "$target"

# --- (d) the Codex hook stops naming portable.md ---
# With no argument inject.sh defaults to both files, so Codex would receive
# portable-claude.md — the cross-harness leak the two-file split prevents.
target="$(fixture codex-both)"
OUT="$target/codex/hooks.json" python3 - <<'PY'
import json, os

path = os.environ["OUT"]
with open(path) as f:
    hooks = json.load(f)
hooks["hooks"]["SessionStart"][0]["command"] = '"${PLUGIN_ROOT}"/inject.sh'
with open(path, "w") as f:
    json.dump(hooks, f, indent=2)
PY
check fail "codex hook passes no payload argument" "$target"

# --- (e) a version sneaks back into a manifest ---
# A declared version is the update signal, so a pinned one silently freezes
# every machine on the cached copy until someone bumps it.
target="$(fixture versioned)"
OUT="$target/.claude-plugin/plugin.json" python3 - <<'PY'
import json, os

path = os.environ["OUT"]
with open(path) as f:
    m = json.load(f)
m["version"] = "0.1.0"
with open(path, "w") as f:
    json.dump(m, f, indent=2)
PY
check fail "version declared in plugin.json" "$target"

# --- (f) the provenance stops naming the plugin root ---
# The payload still arrives and still carries a provenance section, so every
# other assertion passes. What breaks is the one thing a harness without skills
# has to resolve the three files portable.md names by filename alone.
target="$(fixture rootless-provenance)"
OUT="$target/inject.sh" python3 - <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
old = '"The plugin root is `" + root + "`. That is the directory these files were"'
new = '"The plugin root is not named here. That is the directory these files were"'
assert src.count(old) == 1, "inject.sh no longer names the root on one line"
with open(path, "w") as f:
    f.write(src.replace(old, new))
PY
check fail "provenance stops naming the plugin root" "$target"

# A table that silently checked nothing would pass. Guard against it.
if [ "$checked" -lt 7 ]; then
  printf 'FAIL (only %d fixtures ran; the table should hold at least 7)\n' "$checked"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  printf 'ok   %d guidance fixtures classified as expected\n' "$checked"
fi

exit "$fail"
