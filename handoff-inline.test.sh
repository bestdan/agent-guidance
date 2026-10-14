#!/usr/bin/env bash
# Tests hooks/handoff-inline.sh, the Stop hook that reports a handoff pasted
# into the reply instead of written to a file.
# Run: bash handoff-inline.test.sh

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK="$self/hooks/handoff-inline.sh"
export ROOT="$self"

exec python3 "$self/handoff-inline.test.py"
