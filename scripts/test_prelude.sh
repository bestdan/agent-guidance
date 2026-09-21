#!/usr/bin/env bash
# Shared prelude for this repo's *.test.sh suites. Source it first.
#
# A test's result must not depend on the machine it runs on. The suites spawn
# the hook and read files; nothing here should read the developer's real home,
# git config, or agent environment.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

# make_workdir <prefix> -- a temp directory whose path is safe to compare
# against one a script computed for itself.
#
# Usage: work="$(make_workdir guidance-selftest)"
#
# The normalization is the whole point. macOS sets TMPDIR with a trailing
# slash, so interpolating it into a template yields `…/T//prefix.XXXXXX`, and a
# script that resolves its own location with `cd … && pwd` collapses that `//`
# to `/`. Comparing the two then fails on a single character, which reads as the
# code under test being wrong rather than the path being spelled two ways. That
# cost a real debugging session on inject-selftest.test.sh; see
# fix(test): normalize the selftest workdir.
#
# Every environment CI runs in hides it --- the Linux runner sets no TMPDIR and
# takes the `/tmp` default, and the Claude Code sandbox sets `/tmp/claude-501`
# --- so it surfaces only on a developer's macOS machine. That is the argument
# for normalizing everywhere rather than at the one call site that compares
# today: the next suite to compare a path would rediscover it the same way.
#
# The body is a subshell so the `cd` cannot escape into the caller if this is
# ever called outside a command substitution.
make_workdir() {
  (cd "$(mktemp -d "${TMPDIR:-/tmp}/$1.XXXXXX")" && pwd)
}

if [ -z "${AGENT_GUIDANCE_TEST_HOME:-}" ]; then
  AGENT_GUIDANCE_TEST_HOME="$(make_workdir agent-guidance-test-home)"
  export AGENT_GUIDANCE_TEST_HOME
fi
export HOME="$AGENT_GUIDANCE_TEST_HOME"
