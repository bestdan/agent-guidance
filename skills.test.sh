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
#
# The block is validated as a whole, not scanned for two keys. Scanning passes
# on front matter the harness rejects -- `broken: [` is an unclosed flow
# sequence that fails a real YAML load while leaving `name` and `description`
# perfectly readable, so a key-scan reports ok on a skill that silently never
# loads. That is the exact failure this suite exists to catch, so the check has
# to reject the block rather than read around the damage.
#
# Every line must be a top-level `key: value` holding a PLAIN scalar: no
# indentation, no flow collections, no block scalars, no anchors or tags. That
# is narrower than YAML allows and deliberately so -- a SKILL.md's front matter
# needs `name` and `description` and nothing whose correctness depends on
# indentation. `yaml.safe_load` is used as a second opinion WHEN IMPORTABLE, and
# is never the only check: PyYAML is not in the standard library and this repo's
# CI installs nothing, so a check that leaned on it would quietly degrade to no
# check at all on most machines.
check "every skills/*/SKILL.md front matter is valid and carries name+description" ok \
  "$(DIR="$dir" python3 - <<'PY'
import os, sys

try:
    import yaml
except ImportError:
    yaml = None

# Plain scalars only. These open a flow collection, a block scalar, an anchor,
# an alias, a tag, or a directive -- every construct whose validity depends on
# something beyond this one line.
#
# Built with chr(96) rather than a literal backtick: this heredoc sits inside a
# `$(...)` command substitution, where bash still parses a backtick as a legacy
# command substitution even though the heredoc delimiter is quoted. A literal
# one here takes the whole suite out with "unexpected EOF".
INDICATORS = "[]{}|>&*!%@" + chr(96)

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
    with open(path) as f:
        text = f.read()
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
    bad = None
    for line in block.splitlines():
        if not line.strip():
            continue
        if line[:1] in " \t":
            bad = "indented line " + repr(line[:40])
            break
        k, sep, v = line.partition(":")
        if not sep or not k.strip():
            bad = "line is not `key: value`: " + repr(line[:40])
            break
        v = v.strip()
        # A quoted value is plain enough, provided the quotes actually close.
        if len(v) >= 2 and v[0] in "\"'" and v[-1] == v[0]:
            v = v[1:-1]
        elif v[:1] in INDICATORS:
            bad = "value for " + repr(k.strip()) + " is not a plain scalar"
            break
        elif v[:1] in "\"'":
            bad = "unclosed quote in value for " + repr(k.strip())
            break
        if k.strip() in keys:
            bad = "duplicate key " + repr(k.strip())
            break
        keys[k.strip()] = v

    if bad:
        problems.append(entry + ": " + bad)
        continue
    if yaml is not None:
        try:
            loaded = yaml.safe_load(block)
        except yaml.YAMLError as exc:
            problems.append(entry + ": yaml.safe_load rejects the block: " + str(exc)[:60])
            continue
        if not isinstance(loaded, dict):
            problems.append(entry + ": front matter is not a mapping")
            continue
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
#
# Scoped to the table, not the whole README, and matched as a table ROW. The
# skill is named in the Versioning prose as well, so a whole-file substring
# search finds it there and reports ok with the table row deleted -- passing on
# precisely the omission it is written to catch. Narrowing to the section is not
# enough on its own either: the check must require a `|`-leading line, or a
# sentence inside the section would stand in for the row.
check "README's ships table names every skill" ok \
  "$(DIR="$dir" python3 - <<'PY'
import os, re, sys

d = os.environ["DIR"]
root = os.path.join(d, "skills")
if not os.path.isdir(root):
    print("ok")
    sys.exit()

with open(os.path.join(d, "README.md")) as f:
    readme = f.read()

section = re.search(r"^## What it ships$(.*?)^## ", readme, re.S | re.M)
if not section:
    print("README has no '## What it ships' section")
    sys.exit()

rows = [ln for ln in section.group(1).splitlines() if ln.lstrip().startswith("|")]
missing = [
    e for e in sorted(os.listdir(root))
    if os.path.isfile(os.path.join(root, e, "SKILL.md"))
    and not any("skills/" + e in row for row in rows)
]
print("; ".join(missing) if missing else "ok")
PY
)"

printf '%s\n' "$([ "$fail" = 0 ] && echo 'skills.test.sh: all passed' || echo 'skills.test.sh: FAILURES above')"
exit "$fail"
