#!/usr/bin/env bash
# Tests scripts/dev-docs-layout.py, and runs it over this repo's own dev_docs/.
# Run: bash dev-docs-layout.test.sh
#
# The checker is the enforcement half of dev_docs_layout.md. Each fixture pins
# one rule at its boundary, because a layout check that fires on legitimate
# content (a README's template, an ignored plan directory, Finder noise) is one
# people learn to ignore, and one that misses a violation is green while
# checking nothing. The last case runs the checker over this repository, so a
# file added under dev_docs/ that breaks the layout fails this suite.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_py="$self/scripts/dev-docs-layout.py"
work="$(make_workdir dev-docs-layout-test)"
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

# fixture NAME: a fresh ROOT with an empty dev_docs/; echoes the root. The
# fixtures are not git repositories, so the checker walks the filesystem; the
# git-mode cases below build a repository on purpose.
fixture() {
  local root="$work/$1"
  mkdir -p "$root/dev_docs"
  printf '%s\n' "$root"
}

# verdict ROOT: runs the checker on ROOT, keeps its output beside the fixture,
# echoes the exit status.
verdict() {
  python3 "$check_py" "$1" > "$1.out" 2>&1
  echo $?
}

# record DIR NAME CREATED [BODY]: writes a record file with front matter.
record() {
  local dir=$1 name=$2 created=$3 body=${4:-}
  mkdir -p "$dir"
  printf -- '---\ncreated: %s\n---\n\n# Title\n\n%s\n' "$created" "$body" > "$dir/$name"
}

# --- 0. nothing to check, and the usage contract ---
empty="$work/empty"
mkdir -p "$empty"
check "a root with no dev_docs/ passes" 0 "$(verdict "$empty")"
python3 "$check_py" --help > /dev/null 2>&1
check "--help exits 0" 0 $?
python3 "$check_py" "$empty" "$empty" > /dev/null 2>&1
check "two positional arguments exit 2, not a passing 0" 2 $?

# --- 1. dev_docs/tasks/ contents ---
fx="$(fixture tasks-ok)"
mkdir -p "$fx/dev_docs/tasks/foo_plan"
: > "$fx/dev_docs/tasks/.task-config.yml"
: > "$fx/dev_docs/tasks/.task-config.local.yml"
: > "$fx/dev_docs/tasks/fix-the-thing.md"
: > "$fx/dev_docs/tasks/.DS_Store"
check "config files, a _plan/ directory, a flat card, and Finder noise pass" 0 "$(verdict "$fx")"

fx="$(fixture tasks-stray-dir)"
mkdir -p "$fx/dev_docs/tasks/notes"
check "a non-_plan directory under tasks/ fails" 1 "$(verdict "$fx")"

fx="$(fixture tasks-stray-file)"
mkdir -p "$fx/dev_docs/tasks"
: > "$fx/dev_docs/tasks/notes.txt"
check "a non-markdown file loose under tasks/ fails" 1 "$(verdict "$fx")"

# --- 2. unchecked checkboxes ---
fx="$(fixture checkbox)"
printf -- '- [ ] todo item\n' > "$fx/dev_docs/notes.md"
check "a line-start checkbox in a live file fails" 1 "$(verdict "$fx")"
check "the failure names the file and line" ok \
  "$(grep -q 'dev_docs/notes.md: line 1:' "$fx.out" && echo ok || echo missing)"

fx="$(fixture checkbox-plan)"
mkdir -p "$fx/dev_docs/tasks/foo_plan"
printf -- '- [ ] todo item\n' > "$fx/dev_docs/tasks/foo_plan/foo_task_1.md"
check "a checkbox inside a _plan/ directory passes" 0 "$(verdict "$fx")"

fx="$(fixture checkbox-inline)"
printf 'The syntax is a literal `- [ ] item` inside backticks.\n' > "$fx/dev_docs/notes.md"
check "a mid-line checkbox does not count" 0 "$(verdict "$fx")"

fx="$(fixture checkbox-fenced)"
printf 'Template:\n\n```markdown\n- [ ] step one\n```\n\n~~~\n- [ ] step two\n~~~\n' > "$fx/dev_docs/notes.md"
check "a checkbox inside a fenced code block does not count" 0 "$(verdict "$fx")"

fx="$(fixture checkbox-fence-mismatch)"
printf '~~~\n```\n~~~\n- [ ] after the fence\n' > "$fx/dev_docs/notes.md"
check "a fence closes only with its own marker" 1 "$(verdict "$fx")"

# --- 3. record directories ---
fx="$(fixture records-ok)"
record "$fx/dev_docs/decisions" 2026-09-13-a-choice.md 2026-09-13 '## Revisit when'
record "$fx/dev_docs/designs" 2026-09-13-a-change.md 2026-09-13
record "$fx/dev_docs/research" 2026-09-13-a-survey.md 2026-09-13
record "$fx/dev_docs/papercuts_reports" 2026-09-13-triage.md 2026-09-13
: > "$fx/dev_docs/decisions/README.md"
mkdir -p "$fx/dev_docs/research/spike/questions"
printf -- '- [ ] open question\n' > "$fx/dev_docs/research/spike/questions/q1.md"
printf 'anything\n' > "$fx/dev_docs/research/spike/ledger.yml"
check "dated records, READMEs, and a research-spike subtree pass" 0 "$(verdict "$fx")"

fx="$(fixture records-undated)"
record "$fx/dev_docs/designs" a-change.md 2026-09-13
check "an undated file in a record directory fails" 1 "$(verdict "$fx")"

fx="$(fixture records-suffix-date)"
record "$fx/dev_docs/papercuts_reports" triage_2026-09-13.md 2026-09-13
check "a suffix date fails" 1 "$(verdict "$fx")"

fx="$(fixture records-snake)"
record "$fx/dev_docs/designs" 2026-09-13-a_change.md 2026-09-13
check "a snake_case slug fails" 1 "$(verdict "$fx")"

fx="$(fixture records-bad-date)"
record "$fx/dev_docs/designs" 2026-13-40-a-change.md 2026-13-40
check "a date that is not a calendar date fails" 1 "$(verdict "$fx")"

fx="$(fixture records-nested)"
record "$fx/dev_docs/designs/old" 2026-09-13-a-change.md 2026-09-13
check "an undated subdirectory outside research/ fails" 1 "$(verdict "$fx")"

# --- 3b. record bundles: a dated directory carrying the record's artifacts ---
# The shape exists so a research or design session's throwaway scripts have a
# home that is not the repo's runtime scripts/ directory. The date on the
# directory is what freezes the artifacts with the prose, and under research/
# it is also what tells a bundle from a research-spike project.
fx="$(fixture bundle-ok)"
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
mkdir -p "$fx/dev_docs/research/2026-09-13-a-survey/references/raw"
printf 'print(1)\n' > "$fx/dev_docs/research/2026-09-13-a-survey/references/probe.py"
printf 'n,ms\n1,2\n' > "$fx/dev_docs/research/2026-09-13-a-survey/references/raw/run-1.csv"
record "$fx/dev_docs/designs/2026-09-13-a-change" README.md 2026-09-13
mkdir -p "$fx/dev_docs/designs/2026-09-13-a-change/references"
: > "$fx/dev_docs/designs/2026-09-13-a-change/references/bench.sh"
check "a bundle with README.md and a nested references/ tree passes" 0 "$(verdict "$fx")"

fx="$(fixture bundle-anything-in-references)"
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
mkdir -p "$fx/dev_docs/research/2026-09-13-a-survey/references"
printf -- '- [ ] a checkbox in a captured note\n' \
  > "$fx/dev_docs/research/2026-09-13-a-survey/references/capture.md"
: > "$fx/dev_docs/research/2026-09-13-a-survey/references/Undated_Thing.TXT"
check "references/ is not inspected: any name, any suffix, checkboxes and all" 0 "$(verdict "$fx")"

fx="$(fixture bundle-readme-only)"
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
check "a bundle with no artifacts passes; their absence is not observable" 0 "$(verdict "$fx")"
# Deliberate, and pinned so nobody tightens it later. An empty references/ is
# invisible in both listing modes -- git tracks no empty directory and the walk
# collects filenames -- so the only implementable rule is "has at least one
# artifact git sees", which fails a bundle whose captures are gitignored and one
# mid-conversion. Review owns "this should have been a flat file".

fx="$(fixture bundle-beside-flat)"
record "$fx/dev_docs/research" 2026-09-13-a-survey.md 2026-09-13
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
mkdir -p "$fx/dev_docs/research/2026-09-13-a-survey/references"
: > "$fx/dev_docs/research/2026-09-13-a-survey/references/probe.py"
check "a flat record beside a bundle of the same name fails" 1 "$(verdict "$fx")"
check "the failure names the flat file" ok \
  "$(grep -q 'also exists as 2026-09-13-a-survey.md' "$fx.out" && echo ok || echo missing)"

fx="$(fixture bundle-flat-other-dir)"
record "$fx/dev_docs/research" 2026-09-13-a-survey.md 2026-09-13
record "$fx/dev_docs/designs/2026-09-13-a-survey" README.md 2026-09-13
mkdir -p "$fx/dev_docs/designs/2026-09-13-a-survey/references"
: > "$fx/dev_docs/designs/2026-09-13-a-survey/references/probe.py"
check "the same stem in two directories is two records, not a collision" 0 "$(verdict "$fx")"

fx="$(fixture bundle-no-record)"
mkdir -p "$fx/dev_docs/research/2026-09-13-a-survey/references"
: > "$fx/dev_docs/research/2026-09-13-a-survey/references/probe.py"
check "artifacts with no README.md record fail" 1 "$(verdict "$fx")"

fx="$(fixture bundle-loose-file)"
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
: > "$fx/dev_docs/research/2026-09-13-a-survey/probe.py"
check "a file loose in a bundle, outside references/, fails" 1 "$(verdict "$fx")"

fx="$(fixture bundle-other-subdir)"
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
mkdir -p "$fx/dev_docs/research/2026-09-13-a-survey/scripts"
: > "$fx/dev_docs/research/2026-09-13-a-survey/scripts/probe.py"
check "a subdirectory of a bundle other than references/ fails" 1 "$(verdict "$fx")"

fx="$(fixture bundle-created-mismatch)"
record "$fx/dev_docs/decisions/2026-09-13-a-choice" README.md 2026-09-12 '## Revisit when'
check "a bundle README's created must match the directory's date" 1 "$(verdict "$fx")"

fx="$(fixture bundle-decision-no-revisit)"
record "$fx/dev_docs/decisions/2026-09-13-a-choice" README.md 2026-09-13 '## Consequences'
check "a decision bundle without a Revisit when section fails" 1 "$(verdict "$fx")"

fx="$(fixture bundle-vs-spike)"
record "$fx/dev_docs/research/2026-09-13-a-survey" README.md 2026-09-13
mkdir -p "$fx/dev_docs/research/spike/tracks/one"
printf -- '- [ ] open question\n' > "$fx/dev_docs/research/spike/tracks/one/questions.md"
: > "$fx/dev_docs/research/spike/LEDGER.md"
check "a dated bundle and an undated spike project coexist under research/" 0 "$(verdict "$fx")"

fx="$(fixture spike-still-skipped)"
mkdir -p "$fx/dev_docs/research/spike"
printf 'anything\n' > "$fx/dev_docs/research/spike/Not_A_Record.yml"
check "an undated research subdirectory is still the spike skill's to validate" 0 "$(verdict "$fx")"

# --- 4. created matches the filename date ---
fx="$(fixture created-mismatch)"
record "$fx/dev_docs/research" 2026-09-13-a-survey.md 2026-09-12
check "a created that differs from the filename date fails" 1 "$(verdict "$fx")"
check "the failure names both dates" ok \
  "$(grep -q "created: 2026-09-12 does not match the record's date 2026-09-13" "$fx.out" && echo ok || echo missing)"

fx="$(fixture created-missing)"
mkdir -p "$fx/dev_docs/research"
printf '# No front matter\n' > "$fx/dev_docs/research/2026-09-13-a-survey.md"
check "a record with no front matter fails" 1 "$(verdict "$fx")"

fx="$(fixture created-quoted)"
mkdir -p "$fx/dev_docs/research"
printf -- '---\ncreated: "2026-09-13"\nquestion: "why?"\n---\n' > "$fx/dev_docs/research/2026-09-13-a-survey.md"
check "a quoted created value is read" 0 "$(verdict "$fx")"

# --- 5. a decision has a Revisit when section ---
fx="$(fixture decision-no-revisit)"
record "$fx/dev_docs/decisions" 2026-09-13-a-choice.md 2026-09-13 '## Consequences'
check "a decision without a Revisit when section fails" 1 "$(verdict "$fx")"

fx="$(fixture design-no-revisit)"
record "$fx/dev_docs/designs" 2026-09-13-a-change.md 2026-09-13 '## Consequences'
check "a design without one passes; the rule is for decisions" 0 "$(verdict "$fx")"

# --- 6. every violation names the convention ---
fx="$(fixture names-convention)"
record "$fx/dev_docs/designs" a-change.md 2026-09-13
verdict "$fx" > /dev/null
check "the failure output names dev_docs_layout.md" ok \
  "$(grep -q 'dev_docs_layout.md' "$fx.out" && echo ok || echo missing)"

# --- 7. inside a repository, .gitignore decides what is checked ---
# A skill's ignored config directory and a locally ignored plan are legitimate
# content that git never sees; the checker must agree with CI about them.
fx="$(fixture git-ignored)"
git -C "$fx" init -q
printf 'dev_docs/co-review/\ndev_docs/tasks/*\n!dev_docs/tasks/.task-config.yml\n' > "$fx/.gitignore"
mkdir -p "$fx/dev_docs/co-review" "$fx/dev_docs/tasks/foo_plan"
: > "$fx/dev_docs/co-review/.co-review.yml"
: > "$fx/dev_docs/tasks/.task-config.yml"
record "$fx/dev_docs/decisions" 2026-09-13-a-choice.md 2026-09-13 '## Revisit when'
check "ignored skill config and an ignored plan pass in a repository" 0 "$(verdict "$fx")"

fx="$(fixture git-untracked)"
git -C "$fx" init -q
record "$fx/dev_docs/designs" a-change.md 2026-09-13
check "an untracked, unignored violation still fails in a repository" 1 "$(verdict "$fx")"

fx="$(fixture git-ignored-tasks-stray)"
git -C "$fx" init -q
printf 'dev_docs/tasks/*\n' > "$fx/.gitignore"
mkdir -p "$fx/dev_docs/tasks/notes"
check "the tasks/ rule reads the filesystem even when tasks/ is ignored" 1 "$(verdict "$fx")"

# --- 8. this repository's own dev_docs/ passes ---
# The enforcing case. Everything above proves the checker is right; this one
# makes it bind.
python3 "$check_py" "$self" > "$work/corpus.out" 2>&1
corpus=$?
check "this repo's dev_docs/ follows the layout" 0 "$corpus"
[ "$corpus" = 0 ] || sed 's/^/     /' "$work/corpus.out"

if [ "$fail" = 0 ]; then
  printf 'dev-docs-layout.test.sh: all passed\n'
else
  printf 'dev-docs-layout.test.sh: FAILURES above\n'
fi
exit "$fail"
