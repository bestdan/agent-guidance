---
created: 2026-09-13
purpose: conventions for this directory
source: bestdan/agent-guidance dev_docs/decisions/README.md
---

# Decisions

One decision per file: what was decided, why, and what would reopen it. A
decision record is reference material for the future reader who is about to
revisit the choice. It is not guidance for the reader who wants to know what
to do today; that reader gets a convention, which is the live file the
decision supports.

The format is an architecture decision record (ADR) in the sense
[Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
gave it, with the consequences and confirmation sections
[MADR](https://adr.github.io/madr/) adds. The evidence behind the choices in
this file is in `dev_docs/research/2026-09-13-adr-and-design-templates.md`.

## When to write one

Write a decision when a choice has a reason worth keeping and someone could
plausibly want to reverse it later. The sharpest test is the reader in a year
who asks "why is it like this?" and would otherwise have to guess. A choice
that the code makes obvious, or that nobody would revisit, needs no record.

A design that lands produces decisions: each choice the design argued for
becomes one record, written when the design is deleted (see
`../designs/README.md`). A decision can also stand alone, when the choice
was small enough to make without a design.

## What is in one

- **Context.** The forces at play, stated neutrally: the constraint, the
  measurement, the failure that prompted this. Enough that a reader can tell
  whether the forces still hold.
- **Decision.** What was chosen, in the active voice. One paragraph.
- **Consequences.** What follows, good and bad, each tied to the context.
  "Good, because …", "Bad, because …".
- **Revisit when.** The evidence that would reopen this: a measurement
  crossing a line, a dependency going away, a constraint lifting. This is the
  section that makes the record useful later, so it is required, and "never"
  is an acceptable answer only with a reason.
- **Confirmation.** How the decision is held up: a test, a hook, a review
  rule, or nothing. Optional, but say "nothing" rather than omitting it, so a
  future reader knows the decision rests on convention alone.
- **Alternatives**, when they were live: one line each on what was rejected
  and why. Optional; a decision made against no real alternative has none.

Aim for one page. A decision that needs more is usually carrying a design,
and the design belongs in `../designs/` while it is proposed.

## Naming and front matter

`YYYY-MM-DD-<slug>.md`, kebab-case. The date is when the decision was taken
and matches `created`. Dates rather than MADR's `NNNN-` numbers, because the
date is the sort key everywhere else under `dev_docs/` and a number adds a
second sequence to keep unique.

A record that carries artifacts — the script that measured something, the
capture it read, the numbers it produced — becomes `YYYY-MM-DD-<slug>/` with
the decision as its `README.md` and the artifacts under `references/`. The rules
above are unchanged; the date moves to the directory. `dev_docs_layout.md` at
the plugin root has the shape and what does not belong there.

The fields are unchanged; a relative path inside one is not. It resolves from
a file one level deeper, so `convention: ../conventions.md` becomes
`../../conventions.md`, and `supersedes:`/`superseded_by:`, which name a
sibling record by bare filename, become `../<name>.md`.

```yaml
---
created: 2026-09-13
status: accepted # accepted | superseded | deprecated
supersedes: 2026-08-01-old-name.md # when this replaces an earlier decision
superseded_by: 2026-10-02-newer-name.md # set on the old record when replaced
convention: ../conventions.md # the live file this decision supports, if any
---
```

A decision is written once it is taken, so `accepted` is the starting state
and there is no `proposed`. A choice that is still open is a design.

## Lifecycle

A decision is never rewritten. Three changes are allowed, and only these:

- **Superseding.** A new decision replaces this one: the new record carries
  `supersedes:`, this one gets `status: superseded` and `superseded_by:`. The
  rest of this file stays as written.
- **Deprecating.** The decision no longer applies and nothing replaces it:
  `status: deprecated` plus a dated callout at the top saying why.
- **A dated callout** for information that arrived after the decision and
  does not change it: `> [!NOTE] 2026-10-02: …`.

Which one applies: if a reader who acted on this record would now do
something different, supersede or deprecate. Otherwise a callout.

One edit sits outside the rule, because this repo is public: a private repo's
name, or a path, script, issue or PR inside one, is replaced with a
description of it ("a private repo", "a PR-body guard"). The record keeps its
meaning and gets no callout. The name stays in the git history.

A second edit sits outside it for the same reason, that the record keeps its
meaning: a relative link whose target has been deleted, usually a design that
graduated, becomes the bare name in backticks followed by "deleted on
graduation" or the like. The layout checker fails a link that does not
resolve and does not follow a name in backticks.

## Template

```markdown
---
created: YYYY-MM-DD
status: accepted
convention:
---

# <Short title naming the problem and the choice>

## Context

<The forces: constraints, measurements, the failure that prompted this.>

## Decision

<What was chosen, active voice, one paragraph.>

## Consequences

- Good, because <effect, tied to the context>.
- Bad, because <cost, tied to the context>.

## Revisit when

- <The evidence that reopens this.>

## Confirmation

<The test, hook, or review rule that holds this up, or "nothing".>

## Alternatives

- **<Option>:** <why not, one line.>
```

## Index

Generated from each record's front matter and title by
`scripts/dev-docs-layout.py --write-index` at the plugin root, and the layout
check fails while it is out of date. A repo that copies this README keeps the
two markers, empties what is between them, and regenerates the block for its
own records.

<!-- dev-docs-index:start -->
<!-- Generated by scripts/dev-docs-layout.py --write-index from each record's front matter and title. Edit the records, not this block. -->

| Date       | Decision                                                                                                                                                      |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-09 | [A directory's index is generated from its records, and the layout check fails while it is stale](2026-11-09-directory-indexes-are-generated-and-checked.md)  |
| 2026-10-15 | [A public repo names no private repo](2026-10-15-a-public-repo-names-no-private-repo.md)                                                                      |
| 2026-10-14 | ["Handoff" means a file, and a cue-phrase hook backs it](2026-10-14-handoff-means-a-file.md)                                                                  |
| 2026-10-03 | [The list-label check rides `Stop` and blocks once, like the hand-off check](2026-10-03-list-label-check-blocks-like-the-handoff-check.md)                    |
| 2026-09-27 | [The layout checker finds a monorepo's package `dev_docs/` itself](2026-09-27-the-checker-discovers-package-dev-docs.md)                                      |
| 2026-09-27 | [In a monorepo, a decision goes in the package whose code it constrains](2026-09-27-a-decision-lives-with-the-code-it-constrains.md)                          |
| 2026-09-25 | [The hand-off command check rides a `Stop` hook and blocks the stop once](2026-09-25-handoff-command-check-rides-a-stop-hook/)                                |
| 2026-09-23 | [Three of four insider-prose signals were dropped, and the fourth only reports](2026-09-23-three-of-four-insider-prose-signals-were-dropped.md)               |
| 2026-09-23 | [The insider-prose rule lives in one file, and the hook quotes it at run time](2026-09-23-the-insider-prose-rule-lives-in-one-file-and-the-hook-quotes-it.md) |
| 2026-09-23 | [The insider-prose detector is one module with three consumers](2026-09-23-the-insider-prose-detector-is-one-module.md)                                       |
| 2026-09-23 | [Jev may measure the insider-prose rule, and no carrier may depend on it](2026-09-23-jev-is-an-instrument-not-a-hook-dependency.md)                           |
| 2026-09-23 | [A prose check rides the existing write hook rather than adding a handler](2026-09-23-a-prose-check-rides-the-existing-write-hook.md)                         |
| 2026-09-20 | [A guard is widened only after the rule it enforces is](2026-09-20-the-rule-widens-before-the-guard.md)                                                       |
| 2026-09-20 | [A hook's python lives in a file beside the shell, and a linter reads it](2026-09-20-hook-python-lives-in-a-file-beside-the-shell.md)                         |
| 2026-09-20 | [An added line is one the new text has and the old text does not](2026-09-20-added-lines-are-the-new-text-minus-the-old.md)                                   |
| 2026-09-19 | [The body guard registers on the bare `Bash` matcher, with no `if`](2026-09-19-the-body-guard-takes-the-bare-bash-matcher.md)                                 |
| 2026-09-19 | [Enforcement of a convention lives in the repo that owns the convention](2026-09-19-comment-key-check-belongs-here.md)                                        |
| 2026-09-19 | [Code comments are in scope of `writing_about_code.md`](2026-09-19-code-comments-are-in-scope.md)                                                             |
| 2026-09-19 | [A safety guard denies the call and offers no escape hatch](2026-09-19-a-safety-guard-denies-and-has-no-hatch.md)                                             |
| 2026-09-19 | [A record with artifacts is a dated directory, and its artifacts live in `references/`](2026-09-19-a-record-with-artifacts-is-a-directory.md)                 |
| 2026-09-16 | [Two handlers on the matcher, because `if` takes one rule](2026-09-16-two-handlers-because-if-takes-one-rule.md)                                              |
| 2026-09-16 | [`if` narrows the dispatch, and the script's own path test backs it up](2026-09-16-if-narrows-dispatch-and-the-script-tests-the-path.md)                      |
| 2026-09-16 | [The `dev_docs/` pointer is emitted once per session, not once per write](2026-09-16-dev-docs-pointer-fires-once-per-session.md)                              |
| 2026-09-16 | [The `dev_docs/` hook never denies a write, and exits 0 on every path](2026-09-16-dev-docs-hook-never-denies-the-write.md)                                    |
| 2026-09-16 | [The hook matches `Write` and `Edit`, not `Read`](2026-09-16-dev-docs-hook-matches-write-and-edit-not-read.md)                                                |
| 2026-09-16 | [The `dev_docs/` hook emits a pointer, never the layout itself](2026-09-16-dev-docs-hook-emits-a-pointer.md)                                                  |
| 2026-09-16 | [Guidance with a mechanical trigger rides a `PreToolUse` hook, not a skill](2026-09-16-conditional-guidance-rides-a-pretooluse-hook.md)                       |
| 2026-09-13 | [The `dev_docs/tasks/` ignore policy follows the tracker handler](2026-09-13-tasks-ignore-policy-follows-handler.md)                                          |
| 2026-09-13 | [Skill config under `dev_docs/` is ignored through `.gitignore` only](2026-09-13-skill-config-ignored-via-gitignore.md)                                       |
| 2026-09-13 | [Each `dev_docs/` directory carries its own README and template](2026-09-13-per-directory-readmes.md)                                                         |
| 2026-09-13 | [Date first, kebab-case, no type suffix, front matter on every record](2026-09-13-naming-and-front-matter.md)                                                 |
| 2026-09-13 | [The `dev_docs/` layout convention lives in this plugin](2026-09-13-layout-convention-lives-in-the-plugin.md)                                                 |
| 2026-09-13 | [The layout checker ships in the plugin and runs from each repo's own check suite](2026-09-13-layout-checker-runs-from-the-consumer-suite.md)                 |
| 2026-09-13 | [The em-dash cap fails CI; sentence length is reported and never blocks](2026-09-13-em-dash-cap-blocks-sentence-length-reports.md)                            |
| 2026-09-13 | [Decision records are ADRs with a required "revisit when" section](2026-09-13-decisions-are-adrs-with-revisit-when.md)                                        |
| 2026-09-13 | [A date in the filename means a record; no date means a live file](2026-09-13-date-in-filename-means-record.md)                                               |
| 2026-09-13 | [Conventions, decisions, and designs are three different things](2026-09-13-conventions-decisions-designs.md)                                                 |
| 2026-09-12 | [Two skills split by verb, not one combined conventions skill](2026-09-12-two-skills-by-verb.md)                                                              |
| 2026-09-12 | [The repo wins on work-product conventions; session rules hold regardless](2026-09-12-repo-wins-on-work-product.md)                                           |
| 2026-09-12 | [The co-review carrier is the assembled input file, not a stdin segment](2026-09-12-co-review-carrier-is-the-assembled-file.md)                               |

Superseded and deprecated:

| Date       | Decision                                                                                                                 | Status                                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| 2026-10-14 | [Describe a mechanism only in the repo that ships it](2026-10-14-describe-a-mechanism-only-in-the-repo-that-ships-it.md) | superseded by [A public repo names no private repo](2026-10-15-a-public-repo-names-no-private-repo.md) |

<!-- dev-docs-index:end -->
