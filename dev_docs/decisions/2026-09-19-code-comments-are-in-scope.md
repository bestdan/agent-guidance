---
created: 2026-09-19
status: accepted
convention: ../conventions.md
---

# Code comments are in scope of `writing_about_code.md`

## Context

Two issues asked for the comment rule in different files. Issue #40 proposed a
code-comments section in `writing_about_code.md`. Issue #45 proposed the
opposite: that the file name code comments as out of scope, because its opening
already disclaims "the code, the identifiers, the file paths, or quoted output".

The first attempt took #45's side and was wrong. That exclusion list is a list
of artifacts nobody composed as prose: a token, an address, a machine's bytes.
A comment is a sentence written for a reader. Appending it to that list claims a
property the list is not built on, and the file's own opening sentence — "it is
about the communication, not the work" — puts a comment on the communication
side.

The register rules settle it from the other direction. Lead with the answer,
explain the non-obvious rather than the obvious, name things precisely, report a
problem with its consequence, and the voice antipatterns are the rules that make
a comment good. A file that excludes comments has excluded the case where those
rules matter most, because a comment ships with the code and is read by everyone
who touches the line afterwards.

What remains true is narrower than the first attempt claimed. Two questions
were fused: **what the words say** once a comment is written, and **how much
comment a change carries** before the content belongs to the commit body
instead. Only the second is a code-level decision.

The files are delivered differently, which decides where the second question is
answered. `inject.sh` injects `portable.md` and `portable-claude.md` at
`SessionStart` on every machine and in every cloud container.
`writing_about_code.md` is read on demand, by the `authoring` and `reviewing`
skills and by co-review's assembled input. A session writing code has the first
file in context and not the second.

## Decision

`writing_about_code.md` states that code comments are in scope and carries a
`Code comments` section: a comment says the thing itself, and a comment does not
repeat the commit body or the PR description. `portable.md`'s Code section keeps
one operative bullet — how much comment a change carries, and the ticket-key
prohibition — and names `writing_about_code.md` for the register.

There is no line-count budget. "Length is usually misplaced content, not excess
content" already supplies the diagnosis a cap was reaching for, and a numeric cap
is wrong at the edges: a concurrency invariant or a workaround for a named
upstream bug can need two or three lines.

## Consequences

- Good, because the rules that make a comment good are stated once, in the file
  that owns the register, rather than reworded into a second file.
- Good, because the operative half still reaches a session mid-code-write, which
  is the moment the rule applies and the moment `writing_about_code.md` is not in
  context.
- Good, because self-containment is checkable by a reader — no tracker access
  needed — while a line count is arbitrary and invites a cramped single line.
- Bad, because the rule is split across two files, so a reader looking for all of
  it reads the pointer first.
- Bad, because the two halves can drift. Nothing asserts that the `portable.md`
  bullet still matches the section it points at.

## Revisit when

- The `portable.md` bullet and the `Code comments` section are found to disagree,
  which would mean the pointer has become a second copy.
- `writing_about_code.md` starts being delivered at `SessionStart`, which removes
  the delivery asymmetry the split bullet exists to cover.

## Confirmation

Nothing mechanical holds the split in place. `scripts/prose-check.py` measures
the new text for the em-dash cap like any other prose here. The ticket-key half
has a check filed as bestdan/dotfiles#857; the register half rests on review.

## Alternatives

- **Comments out of scope, rules in `portable.md`:** shipped in PR #47 and
  rejected in review by the repo owner and two independent reviewers. The scope
  claim was a category error, and the moved text reworded the "Explain the
  non-obvious" section into a second file.
- **All comment rules in `writing_about_code.md`, nothing in `portable.md`:**
  rejected; it removes the rule from the only file a session writing code has in
  context.
- **A `PreToolUse` handler pointing at `writing_about_code.md` on a source-file
  write:** rejected. The `dev_docs/` handler works because most sessions never
  write under `dev_docs/`; a source-file matcher fires on nearly every write, and
  the route is Claude Code only, so Codex would still need the bullet.
