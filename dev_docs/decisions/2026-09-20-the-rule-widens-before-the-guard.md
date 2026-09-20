---
created: 2026-09-20
status: accepted
convention: ../../portable.md
---

# A guard is widened only after the rule it enforces is

## Context

`hooks/gh-body-guard.sh` shipped covering `--body` alone, because the bullet in
`portable.md` named `--body` alone. The survey behind #52 found the identical
hazard on every free-text `gh` flag: `--title` on `gh pr create`, `gh pr edit`,
`gh issue create`, `gh issue edit`, `gh release create` and `gh release edit`,
and `--notes` on the two `release` commands. A PR title routinely carries a code
span, so `--title` is the one most likely to fire in practice.

The widening was left out of the original change on purpose, and that reasoning
is what this record keeps. `2026-09-19-a-safety-guard-denies-and-has-no-hatch.md`
established that this guard denies with no override. A deny with no hatch is a
hard stop, so the only thing making it tolerable is that a session can predict
it from the written convention. A guard enforcing more than its rule says is one
whose refusals arrive unexplained, and an unexplained refusal is answered from
inside a session by working around the guard rather than by suspecting it.

The re-survey also corrected the table in the issue, which claimed `-t` collided
with nothing. Against gh 2.98.0, `-t` is `--template` — a Go output template —
on `gh api`, `gh project create`, `gh project edit` and every command that
prints JSON, and `-b` and `-n` are `--base` and `--name` on `gh issue develop`.

## Decision

Widen the rule in `portable.md` first, in the same change or an earlier one, and
only then widen the guard, and only as far as the rule reaches. The rule names
the class — any `gh` flag whose value is prose — rather than enumerating flags,
so a flag `gh` adds later is covered by the convention on the day it appears and
the guard is the only thing needing an edit.

Two consequences of that ordering are settled here. The denial names a remedy
that exists for the flag it fired on: `--body-file` for `--body`,
`--notes-file` for `--notes`, and single-quoting for `--title`, which reads no
file. And a shorthand is matched only under the commands that spell it as the
prose flag, keyed on the `gh` subcommand path, because gh reuses single letters
across subcommands.

That shorthand table lists the commands that do spell it that way rather than
the ones that do not. Stated in the positive it goes stale toward allowing a
spelling it has not heard of, which is a missed deny; stated in the negative it
goes stale toward refusing a command nobody could have predicted a refusal for,
which is the failure this whole record exists to avoid.

## Consequences

- Good, because a session that reads the convention can predict every refusal
  the guard will produce. That is the property that substitutes for the escape
  hatch the previous record removed.
- Good, because the rule now outlives the survey. `gh` adds flags; a rule naming
  the class does not need re-editing when it does, and the guard falling behind
  the rule is a coverage gap rather than a contradiction.
- Good, because the shorthand table turned a would-be false positive into a
  passing case: `gh api -t "$(cat fmt.tmpl)"` is a correct command that a
  shorthand match on `-t` alone would have made impossible.
- Bad, because the shorthand table is a snapshot of one `gh` release and will
  drift. It carries its version and survey date, and the drift direction is the
  safe one, but a new command spelling `-t` as `--title` goes unguarded until
  someone re-surveys.
- Bad, because the guard is now narrower than its own rule by construction:
  `--description`, `--desc` and `--readme` carry prose too and are not guarded.
  They are settings on a repo or project rather than text authored per change,
  which is the line drawn here, but the line is a judgement and not a mechanism.

## Revisit when

- `gh` gains a free-text flag on a command this guidance's workflow writes
  through, or renames a shorthand in the table. Either is found by re-running
  the survey, not by reading this record.
- The guard produces a false positive in real use. That would mean the rule and
  the guard have come apart again, and the fix is to narrow the guard to the
  rule rather than to widen the rule to match the guard.

## Confirmation

`gh-body-guard.test.sh` pins the ordering in both directions. Each new flag
carries the four spellings `--body` already had — the flag and its value as
separate words, `--flag=value`, the shorthand, and the shorthand joined to its
value. The collisions are pinned as *allowed* cases, one per command, so a
future widening that drops the command-path check fails the suite. Three cases
assert the denial text: that `--title` is not sent to `--body-file`, that
`--notes` is sent to `--notes-file`, and that the quoted rule names the class.

## Alternatives

- **Widen the guard and leave the rule naming `--body`:** rejected; it is the
  ordering this record exists to forbid, and it produces refusals that cannot be
  derived from the convention.
- **Enumerate the flags in `portable.md` instead of naming the class:**
  rejected; the list is a snapshot of one `gh` release, and prose that needs
  re-editing on every upstream flag addition will not get it.
- **Match shorthands without consulting the subcommand:** rejected; `-t` is a Go
  output template on `gh api` and three other commands, so this would hard-stop
  correct calls with no way past them.
- **Also guard `--description`, `--desc` and `--readme`:** rejected for now;
  they set a repo or project field rather than carrying text written for a
  change, and the guarded set is cheaper to widen later than a false positive is
  to recover from.
