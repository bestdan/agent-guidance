#!/usr/bin/env bash
# Tests the tripwire itself: skills.test.sh is run against copies of the plugin
# directory with one piece of skill wiring broken in each, and its verdict
# compared to an expected one.
# Run: bash skills-selftest.test.sh
#
# Why this exists, in the words of the thing that proved it. Two of the three
# assertions in skills.test.sh shipped VACUOUS and passed anyway:
#
#   - the front-matter check scanned for two keys instead of validating the
#     block, so `broken: [` — an unclosed flow sequence a real YAML load
#     rejects — left `name` and `description` readable and the suite said ok,
#     on a skill the harness would silently skip;
#   - the README check searched the whole file, and the skill is also named in
#     the Versioning prose, so deleting the ships-table ROW still said ok.
#
# Both were caught by review, not by the suite, and a one-off mutation script
# run by hand would not have caught the second either: replacing every
# occurrence at once hides exactly the difference between "named somewhere" and
# "named in the table". So the mutations live here, in CI, where an edit that
# makes an assertion vacuous again fails instead of staying green.
#
# Whole-directory copies, not single-file edits, matching inject-selftest.test.sh:
# skills.test.sh reads SKILL.md files and README.md, so GUIDANCE_PLUGIN_DIR only
# reaches the mutated copy when the copy holds every file the suite reads.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
suite="$dir/skills.test.sh"
fail=0
checked=0

work="$(make_workdir guidance-skills-selftest)"
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

  # A traceback means the suite crashed rather than judged. Both verdicts are
  # then meaningless -- a crash exits non-zero, so it would satisfy every
  # expect_fail row below while proving nothing.
  if printf '%s' "$out" | grep -q 'Traceback'; then
    printf 'FAIL %-40s crashed with a traceback\n' "$name"
    fail=1
    return
  fi

  case "$want" in
    fail)
      if [ "$rc" -eq 0 ]; then
        printf 'FAIL %-40s expected the suite to fail, it passed\n' "$name"
        fail=1
      fi
      ;;
    pass)
      if [ "$rc" -ne 0 ]; then
        printf 'FAIL %-40s expected the suite to pass, it failed:\n%s\n' "$name" "$out"
        fail=1
      fi
      ;;
  esac
}

# Rewrite one file in a fixture with a small python edit read from stdin.
mutate() {
  OUT="$1" python3 -
}

# --- control: an unmutated copy passes ---
# Without this every row below could be satisfied by a suite that fails on any
# copy at all, which would prove nothing about the mutations.
check pass "unmutated copy" "$(fixture pristine)"

# --- (a) the skill is not where the harness looks ---
# skills/<name>/SKILL.md is the discovered layout. Renamed, the skill is
# invisible and nothing reports it.
target="$(fixture misplaced)"
mv "$target/skills/plugin-delivery/SKILL.md" "$target/skills/plugin-delivery/README.md"
check fail "SKILL.md renamed out of the layout" "$target"

# --- (b) front matter that a key-scan reads but a YAML parser rejects ---
# THE regression. `broken: [` opens a flow sequence and never closes it, so a
# real load fails while `name` and `description` stay perfectly readable. A
# suite that scans for keys says ok here; that is the silent skip it exists to
# catch.
target="$(fixture unparseable-front-matter)"
mutate "$target/skills/plugin-delivery/SKILL.md" <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
assert src.startswith("---\n"), "SKILL.md no longer opens with front matter"
with open(path, "w") as f:
    f.write("---\nbroken: [\n" + src[4:])
PY
check fail "front matter parses as keys but not as YAML" "$target"

# --- (c) the ships-table row is deleted, the prose still names the skill ---
# The OTHER regression, and the one a careless mutation hides: the README names
# skills/plugin-delivery in the Versioning prose too, so this fixture removes
# ONLY the table row. A whole-file substring check passes here.
target="$(fixture no-table-row)"
mutate "$target/README.md" <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    lines = f.readlines()
kept = [ln for ln in lines if not (ln.startswith("|") and "skills/plugin-delivery" in ln)]
assert len(kept) == len(lines) - 1, "expected exactly one ships-table row to remove"
assert any("skills/plugin-delivery" in ln for ln in kept), (
    "the prose mention is gone too -- this fixture would then pass for the "
    "wrong reason, proving nothing about the table"
)
with open(path, "w") as f:
    f.writelines(kept)
PY
check fail "ships-table row deleted, prose mention kept" "$target"

# --- (d) front matter is not the first thing in the file ---
# One leading blank line and the block is body text, silently.
target="$(fixture shifted-front-matter)"
mutate "$target/skills/plugin-delivery/SKILL.md" <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
with open(path, "w") as f:
    f.write("\n" + src)
PY
check fail "front matter not on line 1" "$target"

# --- (e) front matter is never closed ---
target="$(fixture unclosed-front-matter)"
mutate "$target/skills/plugin-delivery/SKILL.md" <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
end = src.find("\n---\n", 3)
assert end != -1, "SKILL.md front matter is already unclosed"
with open(path, "w") as f:
    f.write(src[:end] + "\n" + src[end + 5:])
PY
check fail "front matter never closed" "$target"

# --- (f) name disagrees with its directory ---
# Two independent spellings of one identity; a mismatch is drift nothing else
# reports.
target="$(fixture name-drift)"
mutate "$target/skills/plugin-delivery/SKILL.md" <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
old = "\nname: plugin-delivery\n"
assert src.count(old) == 1, "SKILL.md no longer declares name on its own line"
with open(path, "w") as f:
    f.write(src.replace(old, "\nname: delivery\n"))
PY
check fail "name disagrees with its directory" "$target"

# --- (g) the description is emptied ---
# The description is what the harness matches on to decide whether to load the
# skill, so an empty one is a wiring failure wearing content's clothes.
target="$(fixture no-description)"
mutate "$target/skills/plugin-delivery/SKILL.md" <<'PY'
import os, re

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
out, n = re.subn(r"\ndescription: .*\n", "\ndescription:\n", src, count=1)
assert n == 1, "SKILL.md no longer declares description on its own line"
with open(path, "w") as f:
    f.write(out)
PY
check fail "description emptied" "$target"

# --- (h) a valid-but-quoted name is still accepted ---
# The false-positive guard. A check that rejects every variation it did not
# anticipate fails closed on correct skills, which costs more than it saves --
# and every expect_fail row above would still pass for such a check.
target="$(fixture quoted-name)"
mutate "$target/skills/plugin-delivery/SKILL.md" <<'PY'
import os

path = os.environ["OUT"]
with open(path) as f:
    src = f.read()
old = "\nname: plugin-delivery\n"
assert src.count(old) == 1, "SKILL.md no longer declares name on its own line"
with open(path, "w") as f:
    f.write(src.replace(old, '\nname: "plugin-delivery"\n'))
PY
check pass "quoted name still accepted" "$target"

printf '%d mutations checked, %s\n' "$checked" \
  "$([ "$fail" = 0 ] && echo 'skills-selftest.test.sh: all passed' || echo 'skills-selftest.test.sh: FAILURES above')"
exit "$fail"
