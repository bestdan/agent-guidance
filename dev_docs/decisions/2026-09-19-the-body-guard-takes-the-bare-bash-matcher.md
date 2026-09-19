---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# The body guard registers on the bare `Bash` matcher, with no `if`

## Context

`2026-09-16-if-narrows-dispatch-and-the-script-tests-the-path.md` established
the pattern for this plugin's hooks: `if` decides whether the script runs, and
the script decides whether it speaks. It is measured — registered on the bare
`Write|Edit` matcher the `dev_docs` script spawned three times for three writes
under `src/`, and with `if` it spawned none.

That works because the `dev_docs` trigger is a property `if` can test. A file
path is in the tool input, and the harness can glob it.

A `gh --body` call is not that shape. `if` matches a command prefix, and the
command this guard must catch can carry `gh` anywhere: after `&&`, after `;`,
inside a subshell, behind a `cd`. Those are not exotic spellings — they are what
a session reaches for immediately after a simple form is refused, which makes
them the forms a guard can least afford to miss. A guard that holds on the easy
case and fails on the hard one is worse than none, because it earns a trust it
does not have.

## Decision

Register the guard on the bare `Bash` matcher with no `if`, and pay the
dispatch cost down inside the script instead. Two `case` tests in the shell
exit before `python3` is started, so a Bash call with no `gh` and no `--body`
costs one short-lived shell and nothing more.

## Consequences

- Good, because every form of the dangerous command is seen, including the
  compound ones a refused session would try next.
- Good, because the cost is bounded by a string test rather than by the
  harness's matcher, so it can be tuned without changing the registration.
- Bad, because a shell process starts on every Bash tool call in every session
  carrying this plugin. That is a real per-call cost that the `dev_docs`
  handler deliberately avoids.
- Bad, because the pattern in this repo now has two shapes, and a future hook
  author has to decide which applies rather than copying the existing one.

## Revisit when

- `if` gains a condition that can match a command's content rather than its
  prefix, which would restore the narrowing without the blind spot.
- The per-call cost is measured as material in a real session. It has not been:
  the figure that exists is three spawns for three writes, measured for the
  other hook, and nothing here has been timed.

## Confirmation

`gh-body-guard.test.sh` carries the compound forms — `cd /tmp && gh …`,
`echo start; gh …`, an absolute path to `gh` — as denial cases, so a narrowing
`if` added later would not fail the suite but removing the script's own
coverage would. The suite also asserts directly that no handler running this
script carries an `if`, which is the property a tidy-looking edit would undo.

## Alternatives

- **An `if` of `Bash(gh pr comment:*)` and siblings:** rejected; it matches a
  prefix, so every compound form escapes. It would also need one handler per
  surface, because an alternation in `if` matches nothing
  (`2026-09-16-two-handlers-because-if-takes-one-rule.md`).
- **A `PostToolUse` check that reports after the fact:** rejected; the
  substitution has already run and the body is already posted.
