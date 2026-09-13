#!/usr/bin/env bash
# Tests scripts/prose-check.py, and runs it over this repo's own markdown.
# Run: bash prose-check.test.sh
#
# Why this suite exists. The check is the enforcement half of two rules in
# writing_about_code.md that prose alone did not hold (issue #8): an author deep
# in a long document does not stop to re-read the rulebook, and a measured
# rewrite moved the sentence count while leaving the em-dash count untouched.
# A check only replaces the rule if it is right about what it flags, so the
# fixtures below pin the boundary cases rather than the happy path.
#
# The last case is the one that does the enforcing: it runs the check over the
# repository, so a paragraph added in any tracked markdown fails this suite.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_py="$self/scripts/prose-check.py"
work="$(mktemp -d "${TMPDIR:-/tmp}/prose-check-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fail=0
em="—"

check() {
  local desc=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    printf 'ok   %s\n' "$desc"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$desc" "$want" "$got"
    fail=1
  fi
}

# Writes $2 to a fixture file, runs the check on it alone, and echoes the exit
# status. Paths are passed explicitly so no case depends on git or on cwd.
# `local` is split across lines because bash 3.2, which is what macOS ships,
# does not see an earlier name on the same `local` line under `set -u`.
verdict() {
  local name=$1
  local body=$2
  local path="$work/$name.md"
  printf '%s\n' "$body" > "$path"
  python3 "$check_py" "$path" > "$work/$name.out" 2>&1
  echo $?
}

# --- 1. clean prose passes ---
check "prose within both caps exits 0" 0 \
  "$(verdict clean "A short sentence. Another one, with a single ${em} aside ${em} in it.")"

# --- 2. three em-dashes in one paragraph fail ---
# Three is the first count that exceeds one interruption however the dashes
# pair up, which is why the floor sits there and not at two.
check "three em-dashes in one paragraph exits 1" 1 \
  "$(verdict three "One ${em} two ${em} three ${em} four.")"
check "the failure names file and line" ok \
  "$(grep -q 'three.md:1  3 em-dashes' "$work/three.out" && echo ok || echo missing)"

# --- 3. a matched pair is one interruption, and passes ---
# The cap allows one interruption, and the check cannot tell a matched pair from
# two separate dashes. It resolves that in the author's favour: a rule that
# fires on a legitimate aside is one people learn to ignore.
check "two em-dashes in one paragraph exits 0" 0 \
  "$(verdict pair "A sentence with ${em} an aside ${em} inside it.")"

# --- 4. paragraphs are not pooled ---
# Separate paragraphs each get their own cap. Without this the check charges a
# whole document one cap and every long file fails on arithmetic.
check "em-dashes in separate paragraphs do not pool" 0 \
  "$(verdict split "First ${em} aside ${em} here.

Second ${em} aside ${em} here.")"

# --- 5. a tight list is a list, not one paragraph ---
# portable.md is 50-odd bullets with no blank line between them. Reading that as
# one paragraph reported 32 em-dashes in a single "paragraph", which is a true
# count of a unit nobody writes to.
check "tight list items each get their own cap" 0 \
  "$(verdict tight "- First ${em} aside ${em} here.
- Second ${em} aside ${em} here.
- Third ${em} aside ${em} here.")"

# --- 6. a bullet's continuation lines stay with the bullet ---
# The converse of case 5: splitting on every line instead of every bullet would
# hide a violation spread across a wrapped bullet.
check "a wrapped bullet is one paragraph" 1 \
  "$(verdict wrapped "- One ${em} two ${em}
  three ${em} four.")"

# --- 7. code and tables are not prose ---
tick='`'
check "em-dashes inside a fence are ignored" 0 \
  "$(verdict fenced 'Prose.

```
a — b — c — d
```')"
mixed_fence="~~~
${tick}${tick}${tick}
three ${em} em-dashes ${em} in code ${em}
~~~"
check "a fence closes only with the opener marker" 0 \
  "$(verdict mixed-fence "$mixed_fence")"
check "em-dashes in a table row are ignored" 0 \
  "$(verdict table "| a | b |
| --- | --- |
| x ${em} y ${em} z ${em} w | q |")"
check "em-dashes in inline code and link destinations are ignored" 0 \
  "$(verdict markup "Code ${tick}a ${em} b ${em} c${tick}. [label](https://example.test/${em}/${em}/${em}).")"
check "em-dashes in link labels are counted" 1 \
  "$(verdict link-label "[one ${em} two ${em} three ${em}](https://example.test/ok).")"

# --- 8. sentence length reports and never decides the exit code ---
# The split is measured: before the rewrite, 194/641 sentences (30%) ran over
# 25 words; the current result is 176/776 (23%), including the file that states
# the rule. A cap the corpus breaks at that rate is wrong more often
# than unheeded, so it reports until the rate says otherwise.
long_sentence="$(python3 -c 'print("word " * 40 + "end.")')"
check "a 41-word sentence exits 0" 0 "$(verdict long "$long_sentence")"
check "the long sentence is counted in the report" ok \
  "$(grep -qE '^ +1/1 +100% +.*long\.md$' "$work/long.out" && echo ok || echo missing)"
emphasis="One *sentence.* Another sentence."
check "emphasis delimiters do not hide a sentence boundary" ok \
  "$(verdict emphasis "$emphasis" >/dev/null 2>&1; grep -qE '^ +0/2 +0% +.*emphasis\.md$' "$work/emphasis.out" && echo ok || echo missing)"
double_emphasis="First sentence. **Second sentence.**"
check "opening emphasis delimiters allow a sentence boundary" ok \
  "$(verdict double-emphasis "$double_emphasis" >/dev/null 2>&1; grep -qE '^ +0/2 +0% +.*double-emphasis\.md$' "$work/double-emphasis.out" && echo ok || echo missing)"

tracked_fixture="$work/tracked-fixture"
mkdir "$tracked_fixture"
newline_path="$tracked_fixture/line
break.md"
printf 'A short sentence.\n' > "$newline_path"
GIT_CONFIG_GLOBAL=/dev/null git -C "$tracked_fixture" init -q
GIT_CONFIG_GLOBAL=/dev/null git -C "$tracked_fixture" add -- "$newline_path"
(cd "$tracked_fixture" && python3 "$check_py" > "$work/newline.out" 2>&1)
newline_status=$?
check "tracked Markdown paths with newlines are handled" 0 "$newline_status"

# --- 9. the repository's own markdown passes ---
# The enforcing case. Everything above proves the check is right; this one makes
# it bind.
(cd "$self" && python3 "$check_py" > "$work/corpus.out" 2>&1)
corpus=$?
check "every tracked markdown file is within the em-dash cap" 0 "$corpus"
[ "$corpus" = 0 ] || sed 's/^/     /' "$work/corpus.out"

if [ "$fail" = 0 ]; then
  printf 'prose-check.test.sh: all passed\n'
else
  printf 'prose-check.test.sh: FAILURES above\n'
fi
exit "$fail"
