---
created: 2026-09-20
status: accepted
convention: ../conventions.md
---

# An added line is one the new text has and the old text does not

## Context

`hooks/comment-key-context.sh` reports a tracker key in a code comment, and the
rule it enforces is about a comment being _written_. A key that pre-dates the
rule is not a finding. A guard that reports one is the false positive
`portable.md` warns makes a check worse than the prose it replaces, and this
hook runs on every `Write` and `Edit` in every repo a session touches, so the
false positive lands on code nobody in the session wrote.

`PreToolUse` hands the added text cleanly for neither tool, which is the part
the issue (#50) flagged as unsettled:

- **`Edit`** — `new_string` reads as the added text and is not. An edit that
  reindents a block, or that appends a line under a line quoted to make the
  match unique, carries untouched lines through both `old_string` and
  `new_string`.
- **`Write`** — the payload is the whole file. On a new file every line is
  added; on an existing one, every key the file already carries would fire on
  the first unrelated write to it.

The hook has no access to a diff. It runs before the tool call, so the working
tree still holds the old text, and it has no VCS assumption to lean on: a
consumer repo may not be a git repository at all.

## Decision

The script computes the added text itself, the same way for both tools: an
added line is one whose stripped text does not appear, stripped, anywhere in
the old text. The old text is `old_string` for `Edit` and the file on disk for
`Write`. A `Write` whose path does not exist reads as an empty old text, so
every line of a new file is added.

An unreadable existing file also reads as empty, and so reports more than it
should. The cost is a pointer on text the session did not add; the alternative
is silence on the case the guard exists for.

## Consequences

- Good, because the two tools reach one rule. A reader reasons about "the lines
  this change adds" rather than about a per-tool payload shape, and the suite
  pins the same behaviour through both payloads.
- Good, because it needs no diff, no git and no temporary file. The old text is
  in the payload or on disk.
- Good, because a whole-file `Write` to a legacy file is silent, which is the
  write that would otherwise make the hook unusable in an old codebase.
- Bad, because it is a line-set difference, not a diff. A key-bearing
  comment that _moves_ — a block reindented by a different amount is a
  different string, but a block relocated intact is not — is not reported. That
  is a missed finding, which is the safe direction for an advisory hook.
- Bad, because a line that legitimately repeats is attributed to the old text.
  Adding a second `# see PRE-1` where one already exists is silent.
- Bad, because `Write` reads the file from disk, so the hook's answer depends on
  a file the payload does not carry. A path the process cannot read reports as
  a new file.

## Revisit when

- A false positive is reported in real use. That means the line-set rule has
  admitted something the old text did carry, and the fix is a narrower rule
  rather than a quieter one.
- `PreToolUse` starts carrying a diff or the prior content for `Write`, which
  would remove the disk read and the unreadable-file branch with it.

## Confirmation

`comment-key-context.test.sh` pins all four cases directly: a `Write` that
leaves an existing key untouched is silent, a `Write` that adds a second key to
the same file is reported, a `Write` creating a file is reported, and an `Edit`
quoting an existing key as context is silent. Those four are the suite's
statement of this record; a hook that scanned the payload alone passes every
other case in the file and fails exactly these.

A live headless session confirmed the registration on 2026-09-20, the way the
#53 record did, because every case in the suite feeds the script directly and
so passes on a hook the harness never runs. `claude -p --plugin-dir` against
this worktree, writing into `/tmp/claude/comment-key-probe`, which is not a
repository: a `Write` of `# added because PRE-999 asked for it` came back with
the finding quoted verbatim and the file written, which pins both that the
handler fires without an `if` under a matcher whose other handlers carry one,
and that it does not block. The negative control, a comment reading
`# decoded as UTF-8 before the parse`, drew no hook context at all.

## Alternatives

- **Scan `new_string` and `content` whole:** rejected; it reports a comment
  nobody touched on the first write to any file that carries one.
- **Shell out to `git diff` against the working tree:** rejected. It needs the
  consumer repo to be a git repository and the file to be tracked, and it
  compares the tree to `HEAD` rather than the payload to the tree, so a key
  added earlier in the same session reports on every later write.
- **Only report on `Edit`, and stay silent on `Write`:** rejected; a new file
  arrives through `Write`, and a comment written into a new file is the most
  likely place for this rule to be broken.
