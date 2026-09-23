#!/usr/bin/env bash
# Tests scripts/insider_prose.py, the detector behind the insider-prose rule in
# writing_about_code.md.
# Run: bash insider-prose.test.sh
#
# Why this wrapper exists rather than a bare .test.py: scripts/run-tests.sh
# discovers suites with `git ls-files '*.test.sh'`, so a python file on its own
# never runs in CI. gh-body-guard.test.sh is the same pairing.
#
# What the suite is for. The detector's dangerous direction is the false
# positive: it reports on prose someone is in the middle of writing, so a
# signal that fires on a correct sentence teaches its reader to ignore it, and
# an ignored check is worse than an absent one. The good cases are therefore
# assertions and the misses are notes.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT="$self"

exec python3 "$self/insider-prose.test.py"
