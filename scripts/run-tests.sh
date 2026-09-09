#!/usr/bin/env bash
# Runs every *.test.sh in the repo and reports one verdict.
# Run: scripts/run-tests.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 1

fail=0
count=0
while IFS= read -r suite; do
  [ -n "$suite" ] || continue
  count=$((count + 1))
  if bash "$suite" > "${TMPDIR:-/tmp}/agent-guidance-suite.out" 2>&1; then
    printf 'PASS %s\n' "$suite"
  else
    printf 'FAIL %s\n' "$suite"
    sed 's/^/     /' "${TMPDIR:-/tmp}/agent-guidance-suite.out"
    fail=1
  fi
done < <({ git ls-files '*.test.sh'; git ls-files --others --exclude-standard '*.test.sh'; } | sort -u)

printf '%d suites, %s\n' "$count" "$([ "$fail" = 0 ] && echo all passed || echo FAILURES above)"
exit "$fail"
