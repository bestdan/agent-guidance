#!/usr/bin/env bash
# Tests hooks/gh-body-guard.sh, the PreToolUse hook that refuses a gh --body
# argument the shell would run a command substitution inside.
# Run: bash gh-body-guard.test.sh
#
# Why this suite exists. The guard's two failure directions are both quiet. If
# it stops denying, the thing it prevents is silent by construction --- gh exits
# 0 and posts the substitution's output --- so nothing reports the regression. If
# it starts denying too much, it blocks correct commands, and the obvious fix
# from inside a session is to work around the guard rather than to suspect it.
#
# The cases are the boundaries. Quoting is the entire distinction being drawn
# here, so most of them differ from a neighbour by one quote character.
#
# The payloads are built with json.dumps rather than printf. Every interesting
# command in this file contains backticks, double quotes, single quotes or a
# backslash, and a hand-quoted JSON template mangles those into something that
# still parses --- so a broken case would report a passing guard.

set -uo pipefail

# shellcheck source=scripts/test_prelude.sh
. "$(dirname "${BASH_SOURCE[0]}")/scripts/test_prelude.sh"

self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GUARD="$self/hooks/gh-body-guard.sh"
export ROOT="$self"

# The cases are a python program, and it lives in gh-body-guard.test.py beside
# this file. This wrapper is what `scripts/run-tests.sh` discovers -- it globs
# `*.test.sh` -- and what sources the prelude that isolates HOME and the git
# config for the run. `exec` makes the program the exit status without relying
# on it being the last statement.
exec python3 "$self/gh-body-guard.test.py"
