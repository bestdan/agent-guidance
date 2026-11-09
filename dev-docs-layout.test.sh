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
  local dir=$1 name=$2 created=$3 body=${4:-} status=''
  # A decision or a design carries a status, which check_record_body requires,
  # so each fixture gets the starting one for its directory unless the body
  # supplies its own front matter.
  case "$dir" in
    */decisions | */decisions/*) status='status: accepted\n' ;;
    */designs | */designs/*) status='status: proposed\n' ;;
  esac
  mkdir -p "$dir"
  printf -- "---\ncreated: %s\n${status}---\n\n# Title\n\n%s\n" "$created" "$body" > "$dir/$name"
}

# raw FILE CONTENT: writes CONTENT, interpreting printf escapes, to FILE.
raw() {
  mkdir -p "$(dirname "$1")"
  printf -- "$2" > "$1"
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

# A harness writes its working directory into whatever cwd it was launched
# from, so .claude/ appears under tasks/ without anyone authoring it there.
# The set of such tools is open, so the rule is the leading dot rather than the
# name — the .DS_Store above is the same rule, not a separate exemption.
# The directory carries a file, because an empty one passes whatever the
# checker does: check 1 skips the entry and the other checks find nothing to
# read. A checkbox is what catches check 2 descending into it.
fx="$(fixture tasks-harness-dir)"
mkdir -p "$fx/dev_docs/tasks/foo_plan" "$fx/dev_docs/tasks/.claude/.cc-writes"
printf -- '- [ ] pending write\n' > "$fx/dev_docs/tasks/.claude/.cc-writes/log.md"
check "a harness's dot-directory under tasks/ passes" 0 "$(verdict "$fx")"

# The other half of that rule: the config is RECOGNISED, not merely tolerated,
# so a near miss is reported rather than swallowed by the dot skip.
fx="$(fixture tasks-config-near-miss)"
mkdir -p "$fx/dev_docs/tasks"
: > "$fx/dev_docs/tasks/.task-config.yaml"
check "a .task-config file with the wrong extension still fails" 1 "$(verdict "$fx")"

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
printf -- '---\ncreated: "2026-09-13"\nquestion: "why?"\n---\n\n# A survey\n' > "$fx/dev_docs/research/2026-09-13-a-survey.md"
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

# --- 8. a monorepo package's dev_docs/ ---
# One call at the repository root has to cover every package, or a package added
# after the suite was written goes unchecked. So the checker finds them itself,
# and the rules it applies there are the root's minus the root-only entries.
fx="$(fixture package-ok)"
record "$fx/packages/core/dev_docs/decisions" 2026-09-13-a-choice.md 2026-09-13 '## Revisit when'
printf 'See the root copy.\n' > "$fx/packages/core/dev_docs/decisions/README.md"
printf '# Tax layer\n' > "$fx/packages/core/dev_docs/tax-layer.md"
check "a package dev_docs/ laid out like the root passes" 0 "$(verdict "$fx")"

fx="$(fixture package-violation)"
record "$fx/packages/core/dev_docs/designs" a-change.md 2026-09-13
check "a violation in a package dev_docs/ fails" 1 "$(verdict "$fx")"
check "the failure names the path from the repository root" ok \
  "$(grep -q '^packages/core/dev_docs/designs/a-change.md: ' "$fx.out" && echo ok || echo missing)"

fx="$(fixture package-no-root)"
rm -r "$fx/dev_docs"
record "$fx/packages/core/dev_docs/designs" a-change.md 2026-09-13
check "packages are checked when the root has no dev_docs/" 1 "$(verdict "$fx")"

fx="$(fixture package-tasks)"
mkdir -p "$fx/packages/core/dev_docs/tasks/foo_plan"
: > "$fx/packages/core/dev_docs/tasks/.task-config.yml"
: > "$fx/packages/core/dev_docs/notes.md"
check "tasks/ in a package fails; its tooling resolves one location" 1 "$(verdict "$fx")"
check "the failure names the package's tasks/" ok \
  "$(grep -q '^packages/core/dev_docs/tasks: ' "$fx.out" && echo ok || echo missing)"

fx="$(fixture package-handoffs)"
record "$fx/packages/core/dev_docs/.handoffs" 2026-09-13-a-note.md 2026-09-13
check ".handoffs/ in a package fails" 1 "$(verdict "$fx")"

# A dev_docs/ below another one is part of the outer tree, not a second
# package: the outer tree's rules judge it, so it fails as an undated
# subdirectory of a record directory, and only once.
fx="$(fixture package-nested-in-dev-docs)"
record "$fx/dev_docs/designs/dev_docs/designs" 2026-09-13-a-change.md 2026-09-13
check "a dev_docs/ inside a dev_docs/ is not a package" 1 "$(verdict "$fx")"
check "it is reported once, as the outer tree's content" 1 \
  "$(grep -c 'dev_docs/designs/dev_docs' "$fx.out")"

fx="$(fixture package-dot-dir)"
record "$fx/.claude/worktrees/x/dev_docs/designs" a-change.md 2026-09-13
check "a dev_docs/ under a dot-directory is not a package" 0 "$(verdict "$fx")"

# In a repository, git's view decides discovery as it decides everything else,
# and the root-only rule reads the filesystem as check 1 does.
fx="$(fixture package-git)"
git -C "$fx" init -q
printf 'packages/core/dev_docs/drafts/\n' > "$fx/.gitignore"
mkdir -p "$fx/packages/core/dev_docs/drafts"
printf -- '- [ ] unchecked\n' > "$fx/packages/core/dev_docs/drafts/scratch.md"
record "$fx/packages/core/dev_docs/decisions" 2026-09-13-a-choice.md 2026-09-13 '## Revisit when'
check "ignored content in a package passes in a repository" 0 "$(verdict "$fx")"
printf 'packages/core/dev_docs/tasks/\n' >> "$fx/.gitignore"
mkdir -p "$fx/packages/core/dev_docs/tasks"
: > "$fx/packages/core/dev_docs/tasks/.task-config.yml"
check "an ignored tasks/ in a package still fails in a repository" 1 "$(verdict "$fx")"

# Every file git lists is filtered before the checks read it, and the package has
# to be found anyway: a dot-entry under tasks/ is dropped as tooling.
fx="$(fixture package-git-tasks-only)"
rm -r "$fx/dev_docs"
git -C "$fx" init -q
mkdir -p "$fx/packages/core/dev_docs/tasks"
: > "$fx/packages/core/dev_docs/tasks/.task-config.yml"
check "a package holding only tasks/.task-config.yml fails in a repository" 1 "$(verdict "$fx")"

# --- 9. a record has one title, and a decision or design a known status ---
# The index lists each record by its `# ` heading, so a record needs exactly
# one. A README's template shows a heading inside a fence, which is not one.
fx="$(fixture title-none)"
raw "$fx/dev_docs/research/2026-09-13-a-survey.md" '---\ncreated: 2026-09-13\n---\n\nNo heading.\n'
check "a record with no title fails" 1 "$(verdict "$fx")"

fx="$(fixture title-two)"
record "$fx/dev_docs/research" 2026-09-13-a-survey.md 2026-09-13 '# A second title'
check "a record with two titles fails" 1 "$(verdict "$fx")"

fx="$(fixture title-fenced)"
record "$fx/dev_docs/research" 2026-09-13-a-survey.md 2026-09-13 '```markdown\n# Not a title\n```'
check "a heading inside a fence is not a second title" 0 "$(verdict "$fx")"

fx="$(fixture status-bad)"
raw "$fx/dev_docs/decisions/2026-09-13-a-choice.md" '---\ncreated: 2026-09-13\nstatus: proposed\n---\n\n# A choice\n\n## Revisit when\n'
check "a decision with status: proposed fails" 1 "$(verdict "$fx")"

fx="$(fixture status-missing)"
raw "$fx/dev_docs/designs/2026-09-13-a-change.md" '---\ncreated: 2026-09-13\n---\n\n# A change\n'
check "a design with no status fails" 1 "$(verdict "$fx")"

fx="$(fixture status-comment)"
raw "$fx/dev_docs/decisions/2026-09-13-a-choice.md" '---\ncreated: 2026-09-13\nstatus: accepted # accepted | superseded\n---\n\n# A choice\n\n## Revisit when\n'
check "a trailing YAML comment is not part of the status" 0 "$(verdict "$fx")"

# --- 10. path fields and supersession ---
# decide FILE FRONT: a decision titled by its stem, with FRONT as extra
# front-matter lines.
decide() {
  local stem
  stem="$(basename "$1" .md)"
  [ "$stem" = README ] && stem="$(basename "$(dirname "$1")")"
  raw "$1" "---\ncreated: ${stem:0:10}\n$2---\n\n# $stem\n\n## Revisit when\n"
}
fx="$(fixture path-dangling)"
decide "$fx/dev_docs/decisions/2026-09-13-a-choice.md" 'status: accepted\nconvention: ../gone.md\n'
check "a convention: that does not exist fails" 1 "$(verdict "$fx")"

fx="$(fixture feeds-dangling)"
raw "$fx/dev_docs/research/2026-09-13-a-survey.md" '---\ncreated: 2026-09-13\nfeeds: ../designs/2026-09-13-gone.md\n---\n\n# A survey\n'
check "a research feeds: that does not exist fails" 1 "$(verdict "$fx")"

fx="$(fixture supersede-ok)"
decide "$fx/dev_docs/decisions/2026-09-13-old.md" 'status: superseded\nsuperseded_by: 2026-09-14-new.md\n'
decide "$fx/dev_docs/decisions/2026-09-14-new.md" 'status: accepted\nsupersedes: 2026-09-13-old.md\n'
check "a reciprocal supersedes/superseded_by pair passes" 0 "$(verdict "$fx")"

fx="$(fixture supersede-bundle)"
decide "$fx/dev_docs/decisions/2026-09-13-old/README.md" 'status: superseded\nsuperseded_by: ../2026-09-14-new.md\n'
decide "$fx/dev_docs/decisions/2026-09-14-new.md" 'status: accepted\nsupersedes: 2026-09-13-old/\n'
check "a bundle on one side of the pair is the same record either way" 0 "$(verdict "$fx")"

fx="$(fixture supersede-oneway)"
decide "$fx/dev_docs/decisions/2026-09-13-old.md" 'status: superseded\nsuperseded_by: 2026-09-14-new.md\n'
decide "$fx/dev_docs/decisions/2026-09-14-new.md" 'status: accepted\n'
check "superseded_by with no supersedes back fails" 1 "$(verdict "$fx")"

fx="$(fixture supersede-no-target)"
decide "$fx/dev_docs/decisions/2026-09-13-old.md" 'status: superseded\n'
check "status: superseded with no superseded_by fails" 1 "$(verdict "$fx")"

fx="$(fixture supersede-still-accepted)"
decide "$fx/dev_docs/decisions/2026-09-13-old.md" 'status: accepted\nsuperseded_by: 2026-09-14-new.md\n'
decide "$fx/dev_docs/decisions/2026-09-14-new.md" 'status: accepted\nsupersedes: 2026-09-13-old.md\n'
check "superseded_by on a record still accepted fails" 1 "$(verdict "$fx")"

# --- 11. relative links resolve ---
fx="$(fixture links-ok)"
record "$fx/dev_docs/research" 2026-09-13-a.md 2026-09-13
record "$fx/dev_docs/research" 2026-09-13-b.md 2026-09-13 \
  '[a](2026-09-13-a.md#findings) [web](https://example.com) [top](#a) `[code](gone.md)`\n\n[ref]: 2026-09-13-a.md'
check "a resolving link, a URL, an anchor and a link in a code span pass" 0 "$(verdict "$fx")"

fx="$(fixture links-broken)"
record "$fx/dev_docs/research" 2026-09-13-b.md 2026-09-13 'See [the design](../designs/2026-09-01-gone.md).'
check "a link to a file that does not exist fails" 1 "$(verdict "$fx")"
check "the failure names the line and the target" ok \
  "$(grep -q 'line 7: link to ../designs/2026-09-01-gone.md' "$fx.out" && echo ok || echo missing)"

fx="$(fixture links-ref-broken)"
record "$fx/dev_docs/research" 2026-09-13-b.md 2026-09-13 '[ref]: ../gone.md'
check "a reference definition to a missing file fails" 1 "$(verdict "$fx")"

fx="$(fixture links-fenced)"
raw "$fx/dev_docs/research/README.md" '# Research\n\n```markdown\n[x](../designs/<name>.md)\n```\n'
check "a link inside a README template fence is not checked" 0 "$(verdict "$fx")"

# --- 12. the generated index ---
# A README opts in by carrying the markers. The check fails while the block
# differs from what the records generate, --write-index makes it match, and a
# second write changes nothing.
markers='# Decisions\n\n## Index\n\n<!-- dev-docs-index:start -->\n<!-- dev-docs-index:end -->\n'
fx="$(fixture index)"
idx="$fx/dev_docs/decisions/README.md"
decide "$fx/dev_docs/decisions/2026-09-13-old.md" 'status: superseded\nsuperseded_by: 2026-09-14-new.md\n'
decide "$fx/dev_docs/decisions/2026-09-14-new.md" 'status: accepted\nsupersedes: 2026-09-13-old.md\n'
raw "$idx" "$markers"
check "a README whose index block is empty fails" 1 "$(verdict "$fx")"
check "the failure says how to regenerate it" ok \
  "$(grep -q 'run scripts/dev-docs-layout.py --write-index' "$fx.out" && echo ok || echo missing)"
python3 "$check_py" --write-index "$fx" > /dev/null 2>&1
check "--write-index exits 0" 0 $?
check "after --write-index the check passes" 0 "$(verdict "$fx")"
check "the live decision is in the main table" ok \
  "$(grep -q '^| 2026-09-14 | \[2026-09-14-new\](2026-09-14-new.md) |$' "$idx" && echo ok || echo missing)"
check "the superseded one names what replaced it" ok \
  "$(grep -q 'superseded by \[2026-09-14-new\](2026-09-14-new.md)' "$idx" && echo ok || echo missing)"
check "the text outside the markers is kept" ok \
  "$(head -1 "$idx" | grep -qx '# Decisions' && echo ok || echo missing)"
before="$(cksum < "$idx")"
python3 "$check_py" --write-index "$fx" > "$fx.write.out" 2>&1
check "a second --write-index changes nothing" "$before" "$(cksum < "$idx")"
check "and reports no rewrite" 0 "$(grep -c rewrote "$fx.write.out")"
decide "$fx/dev_docs/decisions/2026-09-15-newest.md" 'status: accepted\n'
check "a record added after the write makes the index stale" 1 "$(verdict "$fx")"

fx="$(fixture index-none)"
record "$fx/dev_docs/decisions" 2026-09-13-a-choice.md 2026-09-13 '## Revisit when'
raw "$fx/dev_docs/decisions/README.md" '# Decisions\n'
check "a README without markers has no index and passes" 0 "$(verdict "$fx")"

fx="$(fixture index-malformed)"
raw "$fx/dev_docs/research/README.md" '# Research\n\n<!-- dev-docs-index:start -->\n'
check "a start marker with no end fails" 1 "$(verdict "$fx")"
python3 "$check_py" --write-index "$fx" > /dev/null 2>&1
check "and --write-index leaves it alone" 0 "$(grep -c 'dev-docs-index:end' "$fx/dev_docs/research/README.md")"

fx="$(fixture index-empty-designs)"
raw "$fx/dev_docs/designs/README.md" '# Designs\n\n<!-- dev-docs-index:start -->\n<!-- dev-docs-index:end -->\n'
python3 "$check_py" --write-index "$fx" > /dev/null 2>&1
check "an empty designs/ says none are open" ok \
  "$(grep -q 'No designs are open.' "$fx/dev_docs/designs/README.md" && echo ok || echo missing)"

python3 "$check_py" --bogus "$fx" > /dev/null 2>&1
check "an unknown flag exits 2" 2 $?

# --- 13. this repository's own dev_docs/ passes ---
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
