---
name: testing
description: Conventions for deciding whether a test is worth writing, and for pruning tests that are not. Use when writing, adding or changing a test, when fixing a bug that needs a regression test, when reviewing the tests in a diff, or when asked to "add a test for", "write tests", "prune the tests", "clean up tests", or "remove redundant tests". Do not load at session start.
---

# testing

Loads the file that governs tests: what makes one worth writing, what it may
and may not assert, what it costs to run, and when deleting one is the right
change. It is loaded when a test is about to be written, changed or reviewed,
not at session start, because most sessions never write a test.

Read `${CLAUDE_PLUGIN_ROOT}/testing.md` before writing or editing the first
test. Do not read `writing_about_code.md` for this: the always-on guidance
already carries the prose register, and a test needs no more of it.

A repo's own testing docs (a `dev_docs/testing.md`, a section of `AGENTS.md` or
`CONTRIBUTING`) still come first where they are stricter or more specific, per
the `## Precedence` section in `portable.md`.

`${CLAUDE_PLUGIN_ROOT}` is the plugin's installed directory. Under
`--plugin-dir` it is the checkout itself; `testing.md` sits at its root either
way.
