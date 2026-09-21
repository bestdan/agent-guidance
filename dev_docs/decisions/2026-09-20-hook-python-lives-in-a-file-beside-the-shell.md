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
dprint, with the rule set pinned in `ruff.toml` so a laptop and CI check the
same thing.

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
  embedded form could not be, and it is silent as measured above. The three
  suite cases are what make it findable.
- Bad, because a reader arriving from `hooks.json` now lands on the wrapper and
  has one hop to make. The reasoning stays in the wrapper, which is the file
  that is arrived at, and each program's docstring names the wrapper it belongs
  to.
- Bad, because ruff is a fourth tool a contributor may not have installed. It
  reports SKIP rather than a pass, so a local run says what it did not check,
  and CI covers it either way.
- Bad, because the python embedded in the `*.test.sh` suites is still parsed by
  nothing, and `gh-body-guard.test.sh` is several hundred lines of it. The
  difference is that a suite fails loudly when its own program breaks, so it is
  not the failure this record is about.

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
it. Each suite carries a case that opens the `.py` file next to its wrapper and
compiles it, reporting the path and line on a syntax error and the read error on
an unreadable file, which is what replaces the deleted apostrophe case.

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
