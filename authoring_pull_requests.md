# Authoring Pull Requests

A PR description exists to save the reviewer time. The diff already says what changed. The description says why, and
what a careful reader cannot infer.

Read [`writing_about_code.md`](writing_about_code.md) first — it governs the voice, the evidence rules, and the
precision rules everywhere, this document included. What follows is only what a PR adds: it is prose about a specific
change, aimed at one reader who has to decide whether to approve it.

One test settles every sentence in a PR body: does it change what the reviewer does next? If not, cut it.

## Budget

The body fits on one screen without scrolling. A change that seems to need
more usually needs to be a smaller PR, or the extra content belongs somewhere else.

## Shape

**Title.** Imperative, under 70 characters, follows the **`Git:`** bullet in `portable.md`.
It must stand alone: a reader scanning a list of merged PRs understands the change from the title only.

**First paragraph.** One to three sentences: the problem this solves or the capability it adds, and the approach. This
is the only mandatory section.

**Everything else is earned.** Add a section only when its absence costs the reviewer time.

## Include, when it applies

- **Context an outsider lacks.** Assume the reviewer does not know this area. Give the background that makes the change
  make sense.
- **The non-obvious.** A trade-off, a workaround, an unusual pattern, a decision a reviewer would reasonably question.
  Naming it converts a confused review into a focused one.
- **Verification a reviewer cannot get from CI.** "Ran the migration against a production-sized snapshot; 40s." Never
  "tests pass" or "verified locally" — CI reports that.
- **What you want scrutinized**, when the change has real blast radius. One line. Include the rollback path if the
  change is hard to reverse.
- **Links**: the ticket, the ADR or RFC, the prior discussion, the PR this depends on.

## The body must match the diff

Every claim about what this change does must be visible in the diff. Do not describe intended work, dropped work, or
follow-ups as if they are in this change. Context, links, and verification are the exception — they are why the body
exists.

Re-read the body against the final diff before opening the PR, and again after any push that changes what the PR does. A
body written for the first commit might no longer describe the change.

## Antipatterns specific to a PR body

- Counts of lines, files, or classes changed.
- "Verified locally," "tests pass," "lint is clean" — CI says this.
- A bullet per changed file. That is the Files tab.
- A walkthrough of the whole diff. The reviewer is about to read it.

## Where detail belongs

| Content                         | Home                     |
| ------------------------------- | ------------------------ |
| Why this line, not that line    | Inline diff comment      |
| Why this design, at length      | ADR or RFC, linked       |
| Product or ticket background    | The ticket, linked       |
| Work not in this diff           | A follow-up task         |
| Walkthrough of the whole change | Nowhere — trust the diff |

## Follow the repo's conventions first

Before writing, read, in this order, and follow whichever exist:

1. A pull request template. Search case-insensitively for `pull_request_template` — GitHub's own docs spell it
   lowercase, plenty of repos use `PULL_REQUEST_TEMPLATE.md`, and both work — in `.github/`, the repo root, and
   `docs/`. A `pull_request_template/` directory in any of those three holds several; pick the one matching the
   change.
2. `CONTRIBUTING.md` / `doc/CONTRIBUTION_GUIDELINES.md`
3. `AGENTS.md` or `CLAUDE.md`

Those are the source of truth for the body's required sections and structure. Follow them exactly instead of improvising
a different structure. A template section that genuinely does not apply is omitted per the template's own instructions.
Title format is the **`Git:`** bullet in `portable.md` (see Title grammar below), which a template does not override.
This document governs how to write within that structure, not what the structure is.

## Title grammar

The title's grammar — the Conventional Commits prefix, the bracketed ticket key at the end, which key each
`.task-config.yml` handler uses, `[N/A]`, and when to ask instead of guessing — is the **`Git:`** bullet in
`portable.md`, which every session already carries. This file restates none of it; if the two ever disagree,
`portable.md` is right and this file is stale.

## Closing keyword

**A PR that finishes a tracked issue carries `Closes #<n>` on its own line in the body.** The key in the title is for
the human scanning a list; the keyword in the body is what actually retires the issue, and the two are not
interchangeable.

On a board running the `gh-issue` handler this is the only completion path there is. `/sweep-for-complete`,
`/complete-task`, `/archive-tasks` and `/reconcile-tasks` all decline to act on a `gh-issue` board _because_ they
assume the keyword fired on merge — so a PR that omits it leaves the issue open with nothing downstream to catch it.

The keyword must be the real one GitHub matches — `Closes`, `Fixes` or `Resolves`, followed by `#<n>`. A bare `#<n>`
mention links without closing, which is correct when the PR references an issue it does not finish (a deferral, a
related bug) and wrong when it finishes one.

One PR closing several issues repeats the keyword per issue; `Closes #12, #13` closes only the first.

## Before you open it

- Compare the changed files against what the work was meant to touch. A file nobody asked for is either scope creep or a
  leftover from earlier work — stop and ask, rather than quietly shipping it under this PR's story.
- Read your own body once as the reviewer. Cut every sentence that does not change what the reviewer does next.

## Fallback shape

A repo with no template: write the body in this shape. Adding the file to the repo is a separate, deliberate change —
never a side effect of authoring a PR.

```markdown
<!-- Title: imperative, <70 chars, grammar per the Git bullet in portable.md. -->

Closes #<n>

<!-- Own line, above the summary. Repeat the keyword per issue.
     Delete if this PR finishes no tracked issue. -->

## Summary

<!-- 1-3 sentences: the problem, and the approach. Required. -->

## Why this way

<!-- Trade-offs, workarounds, anything a reviewer would question.
     Delete this heading if there is nothing non-obvious. -->

## Notes for the reviewer

<!-- Verification CI cannot show, what to scrutinize, rollback, links.
     Delete if empty. Keep the whole body to one screen. -->
```
