---
created: 2026-10-15
status: accepted
supersedes: 2026-10-14-describe-a-mechanism-only-in-the-repo-that-ships-it.md
convention: ../conventions.md
---

# A public repo names no private repo

> [!NOTE] 2026-10-17: the dated records under `decisions/` and `research/`
> no longer name private repos. #109 replaced each name with a description,
> under an exception the two directories' READMEs now allow. The Consequences
> bullet saying this decision does not rewrite them predates that.

## Context

This repo is public. On 2026-10-15 its live text named private repos in
`portable.md`, `portable-claude.md`, `README.md`, `dev_docs_layout.md`,
`dev_docs/conventions.md`, `skills/plugin-delivery`,
`.github/PULL_REQUEST_TEMPLATE.md`, and the comments in `inject.sh`,
`inject.test.sh` and `hooks/gh-body-guard.sh`. Some were bare
names. Others pointed at a path or a script inside one. A public reader can
follow none of them, and every one announces that the private repo exists.

Two rules made the practice look sanctioned. The `portable.md` preamble said
rules cite paths in a private repo as their enforcement.
`2026-10-14-describe-a-mechanism-only-in-the-repo-that-ships-it.md` tells an
instruction file to name the owning repo's doc, and exempts naming the hook
that enforces a rule. Both assume the reader can open the owning repo.

## Decision

New and live text in this repo never names a private repo, and never points at a path,
script, issue or PR inside one. Where a rule's enforcement or steps live in a
private repo, the rule is stated alone. Code comments and strings a script
emits count as text. A public repo may still be named and linked. The
describe-a-mechanism rule keeps its pointer for readable owners and names
nothing when the owner is private.

## Consequences

- Good, because a public reader meets no pointer they cannot follow.
- Good, because the plugin's text stops announcing which private repos exist.
- Bad, because a reader on a machine that does carry the private repo loses
  the pointer to the steps, and has to know where to look.
- Bad, because the dated records under `decisions/` and `research/` still name
  private repos. They are snapshots, and this decision does not rewrite them.
- Bad, because anything already merged stays in the public git history. This
  keeps new and live text from adding to it, and nothing more.

## Revisit when

- This repo becomes private, or a named repo becomes public.
- Readers who carry the private repo keep missing steps they used to be sent to.

## Confirmation

Review, using `gh repo view <owner>/<repo> --json visibility` on any repo a
change names. No check enforces it: whether a repo is private is not in the
tree, and a list of private names committed here would be the leak.

## Alternatives

- **Keep the names and accept the disclosure.** That leaves pointers nobody
  outside can follow, which is the cost the describe-a-mechanism rule was
  written to avoid.
- **A check with a deny-list of private names.** Committing the list publishes
  exactly what it protects.
