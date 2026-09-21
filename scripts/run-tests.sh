#!/usr/bin/env bash
# Runs every *.test.sh in the repo, plus the three checks CI runs beside them,
# and reports one verdict.
# Run: scripts/run-tests.sh
#
# The suites alone were never the CI contract. The `tests` job runs this script,
# but `fmt`, `shellcheck` and `lint` are jobs of their own, so a run reporting
# "all passed" on the suites said nothing about any of them --- and a formatting
# break CI rejects read as green here. That is not hypothetical: #53 failed `fmt` on
# three consecutive pushes while this script reported all passed each time.
#
# They run after the suites because they are the cheap ones to fix, so a real
# test failure stays at the top of the output where it is read.
#
# A missing tool is reported as SKIP rather than passed over silently. The
# alternative is the failure the shellcheck job's own comment warns about: a
# green run that checked less than it did yesterday, with nothing saying so. A
# SKIP does not fail the run --- CI still covers both, and a contributor who has
# not installed mise should not be blocked by a formatter --- but it is on its
# own line so nobody reads it as a pass.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

out="${TMPDIR:-/tmp}/agent-guidance-suite.out"
fail=0
count=0
checks=0
skipped=0

# $1 label, $2 the exit status of the command whose output is in $out.
report() {
  if [ "$2" = 0 ]; then
    printf 'PASS %s\n' "$1"
  else
    printf 'FAIL %s\n' "$1"
    sed 's/^/     /' "$out"
    fail=1
  fi
}

while IFS= read -r suite; do
  [ -n "$suite" ] || continue
  count=$((count + 1))
  bash "$suite" > "$out" 2>&1
  report "$suite" "$?"
done < <({ git ls-files '*.test.sh'; git ls-files --others --exclude-standard '*.test.sh'; } | sort -u)

# The three checks CI runs as separate jobs, in one deliberate respect wider than
# the workflow: shellcheck also reads untracked files. CI cannot have any, but a
# new script is untracked at exactly the moment it is worth checking, and this
# is the same discovery the suite loop above already does. The difference only
# ever checks more, so a local pass still implies the CI job passes. dprint and
# ruff need no such adjustment --- both glob the filesystem rather than asking
# git, so both already read a file that is new and untracked.

if command -v shellcheck > /dev/null 2>&1; then
  checks=$((checks + 1))
  # Tracked and untracked are disjoint sets, so neither needs deduplicating.
  { git ls-files -z '*.sh'; git ls-files -z --others --exclude-standard '*.sh'; } \
    | xargs -0 shellcheck -S warning > "$out" 2>&1
  report shellcheck "$?"
else
  skipped=$((skipped + 1))
  printf 'SKIP shellcheck (not installed here; CI still runs it)\n'
fi

# ruff. ruff.toml pins which rules run, so this reads the same selection as the
# CI job, and the workflow pins the version it installs. Nothing pins the local
# one, so a release that changes a rule inside E4/E7/E9/F reaches a laptop before
# it reaches CI --- the remaining direction of a skew that started out both ways,
# with the lint job resolving 0.16.8 against a local 0.16.1. Without ruff.toml it
# would be wider still, since ruff would take a config from wherever it found one
# above the repo.
#
# It is here because three PreToolUse hooks run a python program, and until they
# were files no checker could open them. A syntax error in one is a hook that
# says nothing on every payload and exits 0, which is indistinguishable from a
# hook with nothing to say
# (`dev_docs/decisions/2026-09-20-hook-python-lives-in-a-file-beside-the-shell.md`).
if command -v ruff > /dev/null 2>&1; then
  checks=$((checks + 1))
  ruff check > "$out" 2>&1
  report ruff "$?"
else
  skipped=$((skipped + 1))
  printf 'SKIP ruff (not installed here; CI still runs it)\n'
fi

if command -v dprint > /dev/null 2>&1; then
  checks=$((checks + 1))
  dprint check > "$out" 2>&1
  report "dprint check" "$?"
else
  skipped=$((skipped + 1))
  printf 'SKIP dprint check (not installed here; CI still runs it)\n'
fi

printf '%d suites, %d checks' "$count" "$checks"
[ "$skipped" = 0 ] || printf ', %d skipped' "$skipped"
printf ', %s\n' "$([ "$fail" = 0 ] && echo all passed || echo FAILURES above)"
exit "$fail"
