---
name: authoring
description: Conventions for writing a pull request title, a PR description, or a commit message body. Use when opening a PR, when drafting or editing a PR title or body, when writing or rewording a commit message, or when asked to "write the PR description", "open a PR for this", "draft a commit message", "fix this PR title", or "refresh the PR body". Do not use for general prose about code, which the shared guidance already governs, and do not load at session start.
---

# authoring

Loads the two files that govern a PR title, a PR description, and a commit
message body. It is loaded at PR time, not at session start, because every
session already carries the title grammar in `portable.md` and only a session
about to write a PR needs the rest.

Read both, in this order, before writing:

1. `${CLAUDE_PLUGIN_ROOT}/writing_about_code.md` — the register: lead with the
   answer, say how you know, name things precisely, the voice antipatterns.
2. `${CLAUDE_PLUGIN_ROOT}/authoring_pull_requests.md` — what a PR adds: the
   length budget, the required shape, the body-matches-diff rule, template
   precedence, and the fallback body.

Do not read `reviewing.md`. It states the same conventions as things to check,
for the `agent-guidance:reviewing` skill, and a session writing a PR has no use
for it.

The title's grammar — the Conventional Commits prefix and the bracketed ticket
key — is the **`Git:`** bullet in `portable.md`, already in context.
`authoring_pull_requests.md` cites it and restates none of it. The repo's own
conventions win over both where the `## Precedence` section in `portable.md`
says they do.

`${CLAUDE_PLUGIN_ROOT}` is the plugin's installed directory. Under
`--plugin-dir` it is the checkout itself; the two files sit at its root either
way.
