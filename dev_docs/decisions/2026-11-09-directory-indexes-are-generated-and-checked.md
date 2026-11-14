---
created: 2026-11-09
status: accepted
convention: ../../dev_docs_layout.md
---

# A directory's index is generated from its records, and the layout check fails while it is stale

> [!NOTE] 2026-11-13: an index's header may now name a repo's own generator in
> place of `scripts/dev-docs-layout.py --write-index`, and check 9 accepts it.
> See [the decision on enforcing without the plugin](2026-11-13-adopting-repos-can-enforce-without-the-plugin.md).

## Context

`dev_docs/decisions/` in this repo holds 40 records written over five weeks;
`research/` and `designs/` follow the same shape. Nothing listed them,
so the way to find a decision was a directory listing sorted by date, which
shows slugs, not titles, and says nothing about which records are superseded.
A hand-kept list would drift the first time a record was added without it,
and nothing would notice.

Every record already carries what an index needs: its date in the filename,
`status`, `supersedes` and `superseded_by` on a decision, `question` on
research, `tracks` on a design, and a `#` title. None of those was checked
beyond `created`, so an index built from them would inherit any error in
them. A scan of this repo found every relative link resolving, one
superseded pair naming each other correctly, and two filenames quoted in
backticks that no longer resolve: a design deleted on graduation and a record
in another repo. Records are never rewritten, so those two are correct as
history.

The directory READMEs are canonical copies that other repos copy, and each
repo's records are its own, so an index cannot live in the copied text
without every copy carrying this repo's list.

## Decision

Each record directory carries an `INDEX.md`, generated from its records by
`scripts/dev-docs-layout.py --write-index`, which creates any that is
missing. The plain check regenerates each one in memory and fails when it
differs from the file, and check 3 allows `INDEX.md` beside `README.md`. The
directory's README links it near the top and carries nothing generated. The
same checker now also requires one `#` title per record and a known `status`
on decisions and designs, checks that front-matter path fields resolve and
that a supersession pair names each other, and fails a relative markdown link
that does not resolve. A filename in backticks is not checked. A directory
with no `INDEX.md` is not failed for lacking one.

## Consequences

- Good, because the index cannot drift: adding, retitling, superseding or
  deleting a record without regenerating fails the suite entry every
  consumer already runs, with the command that fixes it.
- Good, because the index is only as right as the front matter, and the
  front matter is now checked, so a dangling `superseded_by` or a broken link
  fails before it reaches the index.
- Good, because a repo copies a canonical README unchanged, and its link to
  `INDEX.md` fails the link check until that repo generates its own, so a
  copy never points at a missing index or at this repo's.
- Good, because the generated file is wholly the tool's, so nobody has to
  know which part of a hand-written file not to touch, and a stale index
  shows as a diff to one generated file.
- Bad, because browsing a directory on GitHub renders the README, not the
  index; the README's link is one click away from it.
- Bad, because a consumer whose records break one of the new rules fails at
  its next plugin update, before it has opted into an index at all. The
  rules were chosen so that this repo's 56 files pass without edits.
- Bad, because a link to a design that later graduates breaks when the design
  is deleted, and the record that links it must be edited.
  `decisions/README.md` and `research/README.md` now allow that one edit.
- Bad, because a citation written in backticks can still go stale unnoticed.

## Revisit when

- A consumer's records hit a new rule often enough that the rule costs more
  than the drift it catches.
- Stale backtick citations turn up in review often enough to justify a check
  that knows which ones are deliberate history.
- Every consumer carries an `INDEX.md`, at which point a record directory
  without one could fail rather than pass.

## Confirmation

Checks 6 to 9 in `scripts/dev-docs-layout.py`, each pinned by
`dev-docs-layout.test.sh`, which also runs the checker over this repo, so a
stale index here fails CI.

## Alternatives

- **A separate generator script with its own `--check`:** two scripts would
  share the file listing and the record parsing, and a consumer would wire two
  entries into its suite instead of one.
- **A generated block between markers in each README:** the canonical README
  would carry this repo's index into every copy, and each copy would have to
  empty and regenerate it; generated and hand-written text would share a
  file.
- **Checking filenames in backticks:** fails on legitimate history in
  immutable records, two cases in this repo alone.
- **A site generator such as log4brains or adr-tools' table of contents:**
  each assumes its own numbering or layout, and would still need the
  integrity checks above.
- **Regenerating from the `dev_docs/` write hook:** an edit to one file
  silently rewriting a second is surprising, and the hook never blocks, so
  it could not hold the index current anyway.
