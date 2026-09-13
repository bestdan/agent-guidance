---
created: 2026-09-12
status: accepted
convention: ../conventions.md
---

# The co-review carrier is the assembled input file, not a stdin segment

## Context

`bestdan/workflow-skills`' co-review dispatches up to five external
reviewers, and four are cut off from repo context by mechanism: `crush` pins
`--cwd <NEUTRAL>`, `agy` trusts only its `--add-dir`, `devin` runs from a
neutral cwd, `copilot` runs in GitHub's cloud. `codex exec` runs in the repo,
but its pointer forbids exploring the filesystem, and whether a dispatch loads
`~/.codex/AGENTS.md` is unverified. The reviewing conventions have to reach
all five. The one artifact every reviewer receives is the assembled `<INPUT>`
file: three read it on stdin, `agy` opens it by path, `devin` takes it with
`--prompt-file`.

## Decision

The conventions go into the assembled file. `scripts/coreview-conventions.sh`
resolves the installed plugin through `scripts/agent-guidance-dir.sh` and
prints the paths of `writing_about_code.md` then `reviewing.md`; the
dispatcher pastes those paths into the `cat` that builds `<INPUT>`, so every
reviewer reads rubric, then conventions, then requests, then diff. Paths are
resolved once before dispatch, never by a script segment inside the dispatch
line, so the reviewer command tails stay byte-identical and the exact-match
allow rules still match.

## Consequences

- Good, because it reaches all five reviewers; a segment wired into the stdin
  pipe reaches three and silently misses `agy` and `devin`.
- Good, because it is the only carrier that reads the files itself rather
  than instructing a model to read them, which makes it the load-bearing one
  for reviewing.
- Good, because it fails soft by exit code: `agent-guidance-dir.sh` exits `3`
  when no installed copy is found, `coreview-conventions.sh` returns the same
  when the copy ships neither file, and the dispatcher drops the segment and
  records `conventions: not attached` on the run summary. Exit `1`, meaning
  `AGENT_GUIDANCE_DIR` is set but wrong, is surfaced rather than swallowed.
- Bad, because the cost is ongoing: measured at 10,509 bytes, about 2.6k
  tokens, per reviewer dispatch, about 13k tokens across a five-reviewer run.

## Revisit when

- The per-dispatch size grows past what a review's value covers; the number
  to watch is the 2.6k tokens above.
- Every reviewer gains trustworthy read access to the repo, which would let
  the conventions be read in place instead of pasted.
- `agy` or `devin` change how they take input, which would change which
  carrier reaches them.

## Confirmation

The exit-code contract of `coreview-conventions.sh` and the
`conventions: not attached` line on the run summary. A dispatch that runs
without the conventions says so where the user reads the result.

## Alternatives

- **A stdin segment:** reaches three reviewers of five.
- **Rely on each reviewer's own context discovery:** four of five have it
  removed on purpose, for safety.
