# Reviewing a Change

How to review a diff and how to write each finding. It is written for a
reviewer that may have nothing but this text and the diff: no repo, no
filesystem, no memory. Everything a rule needs is stated here. The links are
extra reading, never the rule itself.

## What a review checks

- **Correctness.** Bugs, wrong logic, an edge the change does not handle.
- **Contradictions.** A claim in the diff that conflicts with another claim in
  the diff, or with text it quotes or cites, is a correctness bug. This holds
  in documentation and instruction files as much as in code: wrong prose
  changes behaviour.
- **Project conventions.** The change follows the patterns the repo documents,
  not only the ones visible in the diff. A reviewer that can read the repo
  finds those docs on its own: `README`, `CONTRIBUTING`, `AGENTS.md` or
  `CLAUDE.md`, a `dev_docs/` directory, and the code next to the change. A
  reviewer that cannot read the repo checks against the text it has, and marks
  the rest `UNVERIFIED`. A second convention where one exists is a finding.
- **Test-coverage gaps that matter.** A behaviour the change adds or alters
  with no test that would fail if it broke. A test whose assertions would pass
  with the guarded behaviour removed is the same gap with a comment on it.
- **Security and performance** where the change touches them.

Skip pure formatting and issues that pre-date the diff.

## The PR itself is in scope

The title, body, and commit messages follow conventions, and a miss is a
finding like any other. Check, when they are in front of you:

- **Title** is `<type>(scope): <description> [KEY]`: a Conventional Commits
  type (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`) with an optional
  scope, imperative, under 70 characters, and it stands alone. That grammar
  holds whether or not the repo ships a PR template — a template governs the
  body, never the title. A repo that documents its own title convention wins;
  check against that instead.
- **Body** matches the diff. Every claim about what the change does is visible
  in the diff; intended, dropped, or follow-up work is not described as done.
  Context, links, and verification are the exception.
- **Body** opens with the problem it solves or the capability it adds, and the
  approach; it fits on one screen (about 200 words, 400 at most), and carries
  no line counts, no per-file bullets, no walkthrough of the diff, and no
  "tests pass".
- **Commit subjects** use the same type-and-scope grammar, without the ticket
  key — that suffix is the PR title's alone. A commit body says why, not what.

## Blocking or not

Every finding says whether it blocks the merge. `(blocking)` means the change
should not merge as it stands. Otherwise `(non-blocking)`, or `(if-minor)`
when the fix is worth doing only if it turns out cheap.

The decoration is a claim about the merge, not a volume control. Do not mark
a defect `(non-blocking)` to be gentle, and do not mark a preference
`(blocking)` to be heard. A high-confidence typo is still non-blocking; a
medium-confidence data-loss bug is still blocking. How sure you are is not
how much it matters. An `UNVERIFIED` finding is decorated by what it would
cost if true.

## The label

Each finding opens with a conventional comment:

```
<label> [(decorations)]: <subject>
```

Labels: `praise`, `nitpick`, `suggestion`, `issue`, `todo`, `question`,
`thought`, `chore`, `note`. A defect is `issue`, a clear improvement is
`suggestion`, an uncertainty is `question` or `thought`, housekeeping is
`chore`.

Two rules carry the weight:

- **The label is a claim about the finding, not decoration.** The label says
  what the finding is; the decoration says what it costs the merge. Do not
  label a defect `nitpick` to soften it, and do not label a preference `issue`
  to force it.
- **`praise:` is a real label. Use it.** A review that is only defects reads
  as hostile, and it hides which parts of the change are right. Praise a
  specific decision, with the same precision as a defect.

## Writing the finding

The shared prose rules in [`writing_about_code.md`](writing_about_code.md)
apply to every finding. The ones a reviewer cannot do without:

- **One point per comment.** Three findings in one comment get one reply, and
  two are lost.
- **Anchor it.** `file:line` on the new side of the diff, then the issue, then
  the fix. A finding with no anchor and no fix costs the author a round trip.
- **Say how you know.** Separate what you verified from what you inferred, and
  mark a claim the diff cannot settle `UNVERIFIED` rather than assert it or
  drop it. Absence claims ("nothing calls this") are the ones most often
  wrong.
- **State the consequence.** "This reads the file per request" gets argued;
  "so a 5k-row CSV costs a disk read per page view" gets fixed.
- **Comment on the code, not the author.** "This allocates per row", never
  "you allocate per row".

## What this file does not cover

The rest of the prose register (lead with the answer, name things precisely,
no narrator voice) is in `writing_about_code.md`. How to write a PR is in
[`authoring_pull_requests.md`](authoring_pull_requests.md). That file states
the conventions as things to do; this file states them as things to check.
