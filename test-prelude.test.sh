#!/usr/bin/env bash
# Tests scripts/test_prelude.sh, the shared prelude every suite sources.
# Run: bash test-prelude.test.sh
#
# Only make_workdir is covered, and it is covered because nothing else can
# cover it. The helper normalizes a temp path so a suite can compare it against
# one the code under test computed for itself, and the case it normalizes --- a
# TMPDIR ending in a slash --- exists on macOS and in no environment this
# repository's CI runs in. The Linux runner sets no TMPDIR and takes the `/tmp`
# default; the Claude Code sandbox sets `/tmp/claude-501`. So a regression here
# is invisible to every automated run and surfaces only on a developer's
# machine, as a failure that blames the code under test rather than the path.
# That is what happened to inject-selftest.test.sh.
#
# The last case is a drift guard rather than a behaviour test. The helper only
# helps where it is used, and a new suite reaching for the raw call would
# reintroduce the hazard silently --- so the suites are discovered rather than
# listed, the same way scripts/run-tests.sh finds them.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

# The helper under test supplies this suite's own scratch space. That is
# circular only in appearance: a root that is merely writable is all the cases
# below need, and each one re-derives the property it asserts.
root="$(make_workdir test-prelude)"
trap 'rm -rf "$root"' EXIT

check() {
  local desc=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    printf 'ok   %s\n' "$desc"
  else
    printf 'FAIL %s (want %s, got %s)\n' "$desc" "$want" "$got"
    fail=1
  fi
}

# --- make_workdir under the TMPDIR that caused the bug ----------------------
#
# The trailing slash is the whole fixture. Interpolating it into a template
# yields a doubled separator, and any script resolving its own location with
# `cd … && pwd` collapses that, so two spellings of one directory stop
# comparing equal.

slashy="$root/slashy/"
mkdir -p "$slashy"
made="$(TMPDIR="$slashy" make_workdir probe)"

case "$made" in
  *//*) doubled=yes ;;
  *) doubled=no ;;
esac
check "no doubled separator survives a TMPDIR ending in one" no "$doubled"

# The property that matters is not the absence of a doubled separator but
# equality with what the code under test will compute, which is what the
# assertion that failed actually compared.
check "the path equals a cd-and-pwd of itself" ok \
  "$([ "$(cd "$made" && pwd)" = "$made" ] && echo ok || echo differs)"

check "the directory exists and is writable" ok \
  "$([ -d "$made" ] && [ -w "$made" ] && echo ok || echo no)"

# Called outside a command substitution, an unguarded cd would land in the
# caller and move a suite's cwd out from under its relative paths.
before="$PWD"
TMPDIR="$slashy" make_workdir escapee > /dev/null
check "the cd does not escape into the caller" "$before" "$PWD"

# --- the helper only helps where it is used ---------------------------------
#
# Discovered, not enumerated: a hand-kept list of suites goes stale silently,
# which is the failure this file exists to prevent. This suite excludes itself
# because the pattern it searches for appears in the search.

needle='mktemp'" -d"
raw=0
while IFS= read -r suite; do
  [ -n "$suite" ] || continue
  [ "$suite" = "test-prelude.test.sh" ] && continue
  if grep -q "$needle" "$self/$suite"; then
    printf '     %s makes its workdir directly; use make_workdir\n' "$suite"
    raw=$((raw + 1))
  fi
done < <(git -C "$self" ls-files '*.test.sh')

check "no suite builds its workdir directly" 0 "$raw"

printf '%d failures\n' "$fail"
exit "$fail"
