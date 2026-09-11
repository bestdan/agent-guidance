#!/usr/bin/env bash
# Tests the WIRING of every skill this plugin ships: that each one sits where
# the harness looks, and that its front matter is the shape the harness parses.
# Run: bash skills.test.sh
#
# Why this suite exists at all. A skill with broken front matter is not an
# error — the harness skips it and says nothing, so the skill is simply never
# offered and the first sign is a session that does not know something it
# should. That is the same silent-loss shape inject.test.sh guards for the
# payload, and it needs the same treatment.
#
# Scope, as in inject.test.sh: the wiring, never the prose. Nothing here asserts
# what a skill SAYS. The one exception is the description, because an empty or
# missing description is a wiring failure wearing content's clothes — it is what
# the harness matches on to decide whether to load the skill at all.
#
# GUIDANCE_PLUGIN_DIR points the assertions at a copy of the plugin directory,
# matching inject.test.sh, so a self-test can break the wiring in a throwaway
# copy rather than in the repository.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${GUIDANCE_PLUGIN_DIR:-$self}"
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

# --- 1. the skill is where the harness looks ---
# skills/<name>/SKILL.md is the layout Claude Code discovers. A skill one
# directory too deep or named README.md is invisible, with no error.
check "plugin-delivery skill is at skills/<name>/SKILL.md" ok \
  "$([ -f "$dir/skills/plugin-delivery/SKILL.md" ] && echo ok || echo missing)"

# --- 2. every skill's front matter parses, and carries both required keys ---
# Iterating rather than naming plugin-delivery: a second skill added later
# inherits this check instead of shipping unguarded.
#
# `name` must match its directory, because they are two independent spellings of
# the same identity and a mismatch is exactly the kind of drift nothing reports.
check "every skills/*/SKILL.md has parseable front matter with name+description" ok \
  "$(DIR="$dir" python3 - <<'PY' 2>/dev/null
import os, sys

root = os.path.join(os.environ["DIR"], "skills")
if not os.path.isdir(root):
    print("no skills directory")
    sys.exit()

problems = []
found = 0
for entry in sorted(os.listdir(root)):
    path = os.path.join(root, entry, "SKILL.md")
    if not os.path.isfile(path):
        continue
    found += 1
    text = open(path).read()
    # The front matter must OPEN the file: a leading blank line or a stray
    # character ahead of the fence and the block is body text, silently.
    if not text.startswith("---\n"):
        problems.append(entry + ": no opening --- on line 1")
        continue
    end = text.find("\n---\n", 3)
    if end == -1:
        problems.append(entry + ": front matter is not closed")
        continue
    block = text[4:end + 1]
    keys = {}
    for line in block.splitlines():
        if line[:1].strip() and ":" in line:
            k, _, v = line.partition(":")
            keys[k.strip()] = v.strip()
    if keys.get("name") != entry:
        problems.append(entry + ": name is " + repr(keys.get("name")))
    if not keys.get("description"):
        problems.append(entry + ": description is empty or missing")

if found == 0:
    problems.append("skills directory holds no SKILL.md")
print("; ".join(problems) if problems else "ok")
PY
)"

# --- 3. the README lists what the plugin ships ---
# The "What it ships" table is the only index of the plugin's surface, and a
# table that silently omits a skill is how the next person concludes the plugin
# is hooks-only and reasons from a property it no longer has.
check "README's ships table names every skill" ok \
  "$(DIR="$dir" python3 - <<'PY' 2>/dev/null
import os, sys

d = os.environ["DIR"]
root = os.path.join(d, "skills")
if not os.path.isdir(root):
    print("ok")
    sys.exit()

readme = open(os.path.join(d, "README.md")).read()
missing = [
    e for e in sorted(os.listdir(root))
    if os.path.isfile(os.path.join(root, e, "SKILL.md"))
    and "skills/" + e not in readme
]
print("; ".join(missing) if missing else "ok")
PY
)"

printf '%s\n' "$([ "$fail" = 0 ] && echo 'skills.test.sh: all passed' || echo 'skills.test.sh: FAILURES above')"
exit "$fail"
