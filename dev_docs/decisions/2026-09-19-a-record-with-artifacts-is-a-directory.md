---
created: 2026-09-19
status: accepted
convention: ../../dev_docs_layout.md
---

# A record with artifacts is a dated directory, and its artifacts live in `references/`

## Context

Research and design sessions produce non-prose evidence: a script that
measures a latency, the capture it read, the table it produced. The layout had
nowhere to put it. A record directory took `YYYY-MM-DD-<slug>.md` files and
nothing else, so the script went to the repo's `scripts/` — beside code that
CI runs and someone maintains — where nothing says it is a frozen reference
belonging to one record, and where it either rots unnoticed or is kept working
by people who do not know why.

The obvious alternative, an undated `research/<topic>/` directory holding
dated records and a shared `references/`, is the shape the `research-spike`
skill already uses for a spike project. The checker skips subdirectories of
`research/` for exactly that reason, so a topic directory would have been
unenforced and indistinguishable from a spike by anything but its contents.

## Decision

A record that carries artifacts is `YYYY-MM-DD-<slug>/` instead of
`YYYY-MM-DD-<slug>.md`. It holds `README.md`, which is the record with its
usual front matter, and `references/`, which holds the artifacts at any depth
and is not inspected. Nothing else. This applies to `research/`, `designs/`
and `decisions/` alike.

Under `research/`, the date on the directory is what separates a bundle from a
spike project: dated is a bundle and the checker owns it, undated is a spike
and the skill owns it.

## Consequences

- Good, because an artifact is frozen by the same date that freezes the prose
  citing it, and the "date means record" rule extends to a directory with no
  new concept.
- Good, because `scripts/` stays what it claims to be: code the repo runs.
- Good, because the bundle name — leading digit, hyphens — is not a Python
  identifier, so no dotted import can name it and the obvious way to depend on
  a reference script fails. This is weaker than it first looks: JavaScript
  resolves a path and reaches the file fine, and Python still reaches it
  through `sys.path` or `importlib.util.spec_from_file_location`. So the rule
  that a bundle is not importable is a convention with one mechanism behind
  it, not a guarantee.
- Bad, because a record that grows artifacts later has to be converted from a
  file to a directory, which is a rename plus a move.
- Bad, because `research/` now holds two directory shapes with different
  owners, told apart by a date prefix. The checker enforces the split; a
  reader has to know it.

## Revisit when

- The `research-spike` skill starts dating its project directories, which
  would collapse the discriminator.
- Artifacts start being shared across several records on one topic, which the
  bundle deliberately does not support — each record owns its own copy.

## Confirmation

`scripts/dev-docs-layout.py` checks the bundle shape, and
`dev-docs-layout.test.sh` pins each rule at its boundary: a bundle with no
`README.md`, a loose file beside it, a subdirectory that is not `references/`,
a `created` that does not match the directory's date, a flat record left beside
a bundle of the same name, and a dated bundle coexisting with an undated spike.
One fixture pins a non-rule: a bundle with no artifacts passes, because an
empty `references/` is unobservable in both listing modes and the only
implementable check would fail a bundle whose captures are gitignored.

## Alternatives

- **Undated `research/<topic>/references/`:** the shape considered first. It
  collides with the spike namespace, is skipped by the checker entirely, and
  makes one `references/` serve several dated records, so the artifacts drift
  out of agreement with the record that described them.
- **A top-level `research/` directory outside `dev_docs/`:** separates the
  evidence from the prose that explains it, which is the problem being solved.
- **Leave the scripts in `scripts/`, with a naming convention:** a convention
  that lives only in a filename prefix is not enforceable, and the files still
  sit where a maintainer reads them as runtime code.
