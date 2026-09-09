#!/usr/bin/env bash
# Shared prelude for this repo's *.test.sh suites. Source it first.
#
# A test's result must not depend on the machine it runs on. The suites spawn
# the hook and read files; nothing here should read the developer's real home,
# git config, or agent environment.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

if [ -z "${AGENT_GUIDANCE_TEST_HOME:-}" ]; then
  AGENT_GUIDANCE_TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/agent-guidance-test-home.XXXXXX")"
  export AGENT_GUIDANCE_TEST_HOME
fi
export HOME="$AGENT_GUIDANCE_TEST_HOME"
