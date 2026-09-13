---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# A date in the filename means a record; no date means a live file

> [!NOTE] 2026-09-13: the shared checker named under Confirmation landed as
> `scripts/dev-docs-layout.py`; see
> `2026-09-13-layout-checker-runs-from-the-consumer-suite.md`.

## Context

Four repos used `dev_docs/` with no shared rule for which files are kept
current and which are allowed to go stale
(`../research/2026-09-13-dev-docs-survey.md`). About half the dated-by-nature
files carried a date, in two positions, and status lived in prose. The
state-locality rule in `portable.md` already said a file that records a
moment must carry its date in the name; nothing laid the directories out on
that rule.

## Decision

A file named `YYYY-MM-DD-<slug>.md` is a record: it describes a moment, may
go stale forever, and is never rewritten. A file with no date is live: it
describes the present, is kept current, and wins when it disagrees with a
record. Directories are split by which kind they hold.

## Consequences

- Good, because the path alone says whether a file is guidance or history.
- Good, because staleness is visible in a listing instead of discovered by
  reading.
- Bad, because every existing undated record has to be renamed and given
  front matter; the migration is listed per repo in the follow-up issues.

## Revisit when

- A class of file appears that is neither a moment nor kept current, and
  the two kinds stop covering what the directory holds.

## Confirmation

A layout test that checks record directories hold only dated files, in
`dotfiles/scripts/dev_docs_layout.test.sh` today and a shared checker in this
plugin as a follow-up. Until then, review.

## Alternatives

- **A README per directory each stating its own rules, with no shared
  principle:** what `.handoffs/` did; three diverging copies showed where it
  stops scaling.
