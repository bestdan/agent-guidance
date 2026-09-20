---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# A safety guard denies the call and offers no escape hatch

## Context

This plugin's first `PreToolUse` hook advises and never blocks.
`2026-09-16-dev-docs-hook-never-denies-the-write.md` gives two reasons: the
layout is guidance rather than a safety rule, and a denying hook could not
distinguish a write that violates the layout from the write that fixes one.

`hooks/gh-body-guard.sh` faces neither condition. A command substitution inside
a `--body` argument is not a style preference: the shell runs it before `gh` is
reached, `gh` posts the output in place of the code span, and the call exits 0
with nothing reported. The correction is a different command — `--body-file` —
so refusing this one cannot refuse its own remedy.

`bestdan/dotfiles`' `agents/guard_pr_body.py` is the nearest sibling and it does
offer an override: a `<!-- pr-guard: allow -->` marker in the body. That guard
polices whether a PR body follows a style, where a considered exception is a
real category.

## Decision

A hook that enforces a safety rule returns `permissionDecision: deny` with a
reason naming the safe spelling, and carries no override marker. A hook that
carries guidance keeps advising. The distinguishing test is whether a reader
could want the guarded behaviour: if the answer is yes, the rule is guidance and
the hook advises.

The denial reason names `--body-file` rather than single-quoting, even though
single-quoting also stops the substitution. A body is prose and will eventually
contain an apostrophe, so the quoted form is a fix that expires.

## Consequences

- Good, because the one failure mode the rule exists for cannot reach the API.
  It was previously invisible: `gh` reports success either way.
- Good, because the guard also closes a hole in
  `dotfiles/agents/sandbox-network-guard.sh`, which anchors on `(^|[;&|])` and
  so never sees a network command inside a backtick.
- Good, because refusing without a hatch keeps the rule's meaning intact. A
  marker would be a way to request exactly the behaviour being prevented.
- Bad, because a false positive is a hard stop with no way past it in the
  moment. The test suite carries the safe spellings as cases for that reason,
  and the scanner deliberately ignores `${...}`, which is expansion rather than
  execution.
- Bad, because the deny reaches Claude Code only. `codex/hooks.json` registers
  `SessionStart` alone, so a Codex session has the prose and nothing else.

## Revisit when

- A legitimate use for a substitution in a `--body` argument appears, which
  would make this guidance rather than a safety rule and move it back to
  advising.
- Codex registers `PreToolUse`, at which point the guard can cover the audience
  the rule already reaches.

## Confirmation

`gh-body-guard.test.sh` pins both directions: the dangerous spellings deny with
a reason, and the safe ones — single quotes, an escaped backtick, `--body-file`,
plain prose — pass. It also asserts the hook exits 0 and stays silent on a
payload it cannot parse, so a script bug cannot block a session's commands.

A live headless session confirmed the registration: `claude -p --plugin-dir`
against this checkout, from a directory that is not a repository, refused the
dangerous command and returned the reason verbatim. The command never ran. The
suite cannot reach that, because every case there feeds the script directly.

## Alternatives

- **Advise rather than deny, as the `dev_docs` handler does:** rejected; the
  behaviour is silent and irreversible once posted, so a pointer arrives too
  late to matter.
- **An override marker, as `guard_pr_body.py` has:** rejected; there is no case
  where the guarded behaviour is wanted, and the safe spelling is always
  available.
- **Widening the scan to `${...}`:** rejected; parameter expansion is not
  command execution, and the rule in `portable.md` names backticks and `$(`.
