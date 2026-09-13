---
name: reviewing
description: Conventions for reviewing a diff, a pull request, or a proposed change, and the format of each finding. Use when asked to review, critique, or check a change, to write review comments, to do a code review, or to answer "does this look right", "anything wrong with this diff", or "can you look over this PR" about a change. Do not use for writing the PR itself, and do not load at session start.
---

# reviewing

Loads the two files that govern a review: what a review checks, how each
finding is labelled, and the prose every finding is written in. It is loaded
when a review starts, not at session start, because most sessions never
review anything.

Read both, in this order, before writing a finding:

1. `${CLAUDE_PLUGIN_ROOT}/writing_about_code.md` — the register: lead with the
   answer, say how you know, name things precisely, the voice antipatterns,
   and the three rules for feedback on someone else's code.
2. `${CLAUDE_PLUGIN_ROOT}/reviewing.md` — what a review checks, the PR title
   and body as review scope, the blocking decoration, the conventional-comment
   label, and how to anchor a finding.

Do not read `authoring_pull_requests.md`. It states the same conventions as
things to do, for the `agent-guidance:authoring` skill; `reviewing.md` already
carries the checkable form of each one.

`reviewing.md` is written for a reviewer that may have nothing but the text
and the diff. A reviewer that can read the repo still checks the repo's own
documented conventions first, per the `## Precedence` section in
`portable.md`, and marks what it cannot verify `UNVERIFIED`.

`${CLAUDE_PLUGIN_ROOT}` is the plugin's installed directory. Under
`--plugin-dir` it is the checkout itself; the two files sit at its root either
way.
