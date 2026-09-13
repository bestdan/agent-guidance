---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# Date first, kebab-case, no type suffix, front matter on every record

> [!NOTE] 2026-09-13: the shared checker named under Confirmation landed as
> `scripts/dev-docs-layout.py`; see
> `2026-09-13-layout-checker-runs-from-the-consumer-suite.md`.

## Context

The survey found prefix dates in most directories and suffix dates in one,
snake_case and kebab-case mixed inside single directories, a `-design`
suffix on some files and not others, and status carried as prose lines that
nothing could check. `dev_docs/tasks/` is the exception: its tooling resolves
slugs by filename stem and fixes snake_case in its schema.

## Decision

Records and designs are `YYYY-MM-DD-<slug>.md`, kebab-case, no type suffix.
Live files are `<slug>.md`. `dev_docs/tasks/` keeps snake_case. Every record
and design carries Obsidian YAML front matter with at least `created`, which
matches the filename date, and the fields its directory's README names.

## Consequences

- Good, because a listing sorts by time and a stale file is visible.
- Good, because a `created` that must match the filename is a check; a bold
  `Drafted:` line is not.
- Bad, because this is the one decision that costs a migration in every
  repo: renames and front matter on every existing record.

## Revisit when

- A tool that reads `dev_docs/` needs a different front-matter shape, which
  would be a reason to change the fields but not the rule that they exist.

## Confirmation

The filename-pattern and `created`-matches-date checks in the shared
checker, when it exists. Review until then.

## Alternatives

- **Type suffixes (`-design.md`):** the directory already says it.
- **Prose status lines:** the status quo; unverifiable.
