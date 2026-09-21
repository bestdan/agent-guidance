---
created: 2026-09-20
status: accepted
convention: ../conventions.md
---

# A hook's python lives in a file beside the shell, and a linter reads it

## Context

Three `PreToolUse` hooks carried their whole program as a single-quoted argument
to `python3 -c`: `hooks/dev-docs-context.sh`, `hooks/gh-body-guard.sh` and
`hooks/comment-key-context.sh`, together around 400 lines. Nothing parsed any of
it. shellcheck sees one opaque argument; a python checker sees no `.py` file to
open. The shell half of each hook had a syntax check, a linter and CI behind it,
and the python half had none of the three.

The failure that exposes this is silent by construction. A truncated or
malformed program reaches `python3` as a syntax error, `2>/dev/null` swallows
the message, and the wrapper still exits 0, which is deliberate: a `PreToolUse`
hook that exits nonzero blocks the tool call
(`2026-09-16-dev-docs-hook-never-denies-the-write.md`). The hook then says
nothing on every payload and the harness reports nothing. A broken hook and a
hook with nothing to say are the same observation.

It has cost once already. While #50 was being written, a code comment reading
"the rule's reason" ended the enclosing quote. Every positive case in
`comment-key-context.test.sh` flipped to silent at the same moment, which is how
it was caught: eleven failures that said something had broken and nothing about
what.

shellcheck does catch that one break. Measured against a deliberately broken
copy, `SC1011 (warning): This apostrophe terminated the single quoted string!`
names the apostrophe and the line, with three parse errors behind it. That is
one full `scripts/run-tests.sh` away rather than one suite away, and it covers
only the apostrophe. A genuine python syntax error, an undefined name on a
branch no test reaches, or a typo in a key of the emitted JSON were all
invisible.

One thing the extraction had to preserve. The `case` tests in the two wrappers
that have them exist so python never starts on most calls, and the measurement
behind that shape is a decision of its own
(`2026-09-19-the-body-guard-takes-the-bare-bash-matcher.md`).

## Decision

Each hook's program is a `.py` file beside its wrapper, run as
`python3 "$here/<name>.py"` with the payload handed over in `PAYLOAD`. The shell
keeps only what has to be shell: reading the payload, the `case` prefilter where
there is one, the environment it passes, and `exit 0`. A python linter runs over
the repo from `scripts/run-tests.sh` and from a `lint` job in CI, reporting SKIP
locally when absent in the shape the runner already uses for shellcheck and
dprint. `ruff.toml` pins the rule selection and the CI job pins the version it
installs; nothing pins the local version, so a release that changes a rule
inside the selection reaches a laptop before it reaches CI.

The wrapper still discards the program's stderr and still exits 0 on every path,
so a missing, unreadable or unparsable `.py` file fails exactly as quietly as
the embedded form did. Measured on 2026-09-20 with `hooks/gh-body-guard.py`
moved out of the way: a payload whose `gh pr comment` body carries a backtick
substitution produced no output and exit 0, so the command it exists to refuse
is allowed and nothing says why. That is the same silence the never-block rule
buys everywhere else, and it is unconditional, so the argument for extracting is
not that it fails louder. The argument is that the failures become findable
before they ship.

## Consequences

- Good, because the quoting hazard is gone rather than guarded. A `.py` file has
  no enclosing shell quote, so no character in it can terminate anything. The
  apostrophe case in `comment-key-context.test.sh` is deleted rather than left
  passing vacuously, and each of the three suites gains a case that reads the
  `.py` file and reports the file and line of a syntax error.
- Good, because a checker applies at all. On its first run over this repo ruff
  reported `E741` in `scripts/dev-docs-layout.py`, in a file that had been read
  by nothing but its own tests since it was written.
- Good, because the programs are now testable directly rather than only through
  a shell wrapper and a JSON payload on stdin. `comment_at()` in
  `hooks/comment-key-context.py` is a pure function with a dozen boundary cases
  pinned today through three layers of process.
- Good, because the workarounds the enclosing quote forced are gone.
  `hooks/gh-body-guard.py` spells a backslash, a newline, a double quote and an
  apostrophe as themselves instead of as `chr(92)`, `chr(10)`, `chr(34)` and
  `"\x27"`, and the rule in `hooks/comment-key-context.py` forbidding an
  apostrophe anywhere in the file is deleted.
- Bad, because there is a new failure mode. The wrapper can be installed and
  current while the program beside it is missing or unreadable, which the
  embedded form could not be, and it is silent as measured above. Two suite
  cases per hook divide that: one compiles the `.py` file so a broken program is
  found before it ships, and one runs a wrapper-only copy so the silence itself
  is pinned rather than only measured once by hand.
- Bad, because a reader arriving from `hooks.json` now lands on the wrapper and
  has one hop to make. The reasoning stays in the wrapper, which is the file
  that is arrived at, and each program's docstring names the wrapper it belongs
  to.
- Bad, because ruff is a fourth tool a contributor may not have installed. It
  reports SKIP rather than a pass, so a local run says what it did not check,
  and CI covers it either way.
- Bad, because the python still embedded in the `*.test.sh` suites is parsed by
  nothing. That is now the small helpers only: `gh-body-guard.test.py` took the
  same move as the hooks, for a reason of its own rather than this record's. Its
  subject is quoting, and inside a single-quoted shell argument it could not
  write a quote, so its cases spelled `chr(39)`, `chr(34)` and `chr(92)` for the
  characters they assert on. The helpers that stay are readers sitting beside the
  assertion they feed, and a break in one is red rather than silent: the suite
  compares an empty verdict against an expected one. Their `2>/dev/null` is gone
  so the break also names its own line, which is what the other half of this was
  about.

## Revisit when

- A hook program acquires a second caller or needs to share code with another.
  A file beside one wrapper is the right shape for exactly one caller; two want
  a module and an import path, which is a different decision.
- The prefilter leaves the shell, for whatever reason. The wrapper's remaining
  job would then be the `exit 0` discipline alone, and `hooks.json` naming the
  `.py` file directly becomes worth measuring against it.
- `PreToolUse` stops treating a nonzero exit as a block. The redirect and the
  unconditional `exit 0` are both downstream of that rule, and without it a
  broken program could report itself.

## Confirmation

`scripts/run-tests.sh` runs ruff over the repo and the three hook suites beside
it. Each suite carries two cases in place of the deleted apostrophe one. The
first opens the `.py` file next to its wrapper and compiles it, reporting the
path and line on a syntax error and the read error on an unreadable file. The
second copies the wrapper alone into a temp directory, feeds it a payload that
clears the `case` prefilter, and asserts exit 0 with empty output, so the
never-block guarantee holds on the new failure path and not only on the old
ones. That case is not vacuous: the same copy with its trailing `exit 0` removed
exits 2, because python is genuinely reached and genuinely fails to find the
program.

Dropping `2>/dev/null` from the python helpers had a side effect worth recording,
because it says the redirect was hiding more than noise. `inject-selftest.test.sh`
and `skills-selftest.test.sh` run their suite against deliberately broken copies
of the plugin and treat a `Traceback` in the output as a crash rather than a
verdict. With the redirect in place no traceback could ever reach them, so that
tripwire had never been able to fire. Unmuted, it fired at once, on one mutation:
the helper reading `hooks/hooks.json` indexed `["SessionStart"]` and raised when
the mutation deleted it, so the suite reported which file it was reading rather
than what was wrong with it. Both registration helpers now use `.get` and print a
verdict, and the tripwire is live for the first time. The mutation is still
rejected, which is the half a green selftest does not show: run by hand against
the same fixture, the suite exits 1 with twenty `ok` lines and
`FAIL hooks.json registers inject.sh on SessionStart (want ok, got no
SessionStart entry in hooks/hooks.json)`. Before the fix that line read
`want ok, got` with the cause on a discarded stream.

A live headless session confirmed the registration on 2026-09-20, as the sibling
records did, because every case in the three suites feeds a wrapper directly and
so passes on a hook the harness never runs. `claude -p --plugin-dir` against this
worktree, in `/tmp/claude/hook-probe-60`, which is not a repository: all three
hooks fired with their programs in files. The comment-key hook quoted its finding
with the line number, the `dev_docs/` hook emitted the pointer with the plugin
root resolved to the worktree, and the `gh` guard refused a `gh pr comment`
whose double-quoted `--body` carried a backtick substitution, with the full
reason. The two writes still landed, which is the advise-never-deny half.
One thing the probe settles that no suite can: the refusal held under
`--permission-mode acceptEdits` with `Bash(gh:*)` allowed, so a hook's deny
outranks a permission allow rather than racing it.

Two measurements are the record's own, both on 2026-09-20 against this worktree.
The wrapper resolves its program from `BASH_SOURCE` rather than the cwd: fed a
`dev_docs/` write payload from an unrelated directory, `hooks/dev-docs-context.sh`
emitted the pointer with the plugin root resolved correctly. And the failure mode
above is as described: with the program moved away, the guard wrapper printed
nothing and exited 0 on a payload it denies when the program is present.

## Alternatives

- **Keep it embedded and rely on shellcheck:** rejected. SC1011 covers the
  apostrophe and nothing else, and the case that broke is the only one of its
  class.
- **Point `hooks.json` at the `.py` file directly:** rejected. The prefilter has
  to run before python starts, and the `exit 0` on every path has to be
  somewhere that a python traceback cannot reach.
- **Move the programs under `scripts/` and import them:** rejected. Each has one
  caller, sitting next to it, and an import would add path work at hook time for
  no reader's benefit.
- **Let stderr through so a broken program is visible:** rejected for now. On
  exit 0 the harness does not surface a hook's stderr, so it buys nothing at
  runtime; the linter is the tier that reports these.
