#!/usr/bin/env bash
# Tests hooks/copyable-command.sh, the Stop hook that reports a `! <command>`
# that will not survive a copy out of the terminal.
# Run: bash copyable-command.test.sh
#
# The payloads are built with json.dumps rather than printf: the commands under
# test carry backslashes and backticks, which a hand-quoted template mangles.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOOK="$self/hooks/copyable-command.sh"
export ROOT="$self"

exec python3 "$self/copyable-command.test.py"
