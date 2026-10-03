#!/usr/bin/env bash
# Tests hooks/list-labels.sh, the Stop hook that reports a list number
# that names two items in one reply.
# Run: bash list-labels.test.sh

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK="$self/hooks/list-labels.sh"
export ROOT="$self"

exec python3 "$self/list-labels.test.py"
