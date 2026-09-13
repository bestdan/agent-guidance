---
created: 2026-09-13
status: accepted
convention: ../../dev_docs_layout.md
---

# Each `dev_docs/` directory carries its own README and template

## Context

How to write a decision is not how to write a design, and one umbrella file
carrying every directory's rules and templates was long before it was
complete. `.handoffs/README.md` already showed the shape that works: the
rules sit where the writer is. It also showed the cost: three copies across
repos had already diverged.

## Decision

`dev_docs_layout.md` at the plugin root carries the shared rules only. Each
of `designs/`, `decisions/`, `research/`, and `.handoffs/` carries a
`README.md` with that directory's purpose, when to write a file, what goes
in one, naming and front matter, lifecycle, and a template. The canonical
copies live in `bestdan/agent-guidance`; a repo copies the ones it uses, and
each copy names its source in front matter.

## Consequences

- Good, because the writer finds the rules and the template in the directory
  they are writing into.
- Good, because the umbrella stays short enough to read in full.
- Bad, because copies drift. The `source:` field says where the canonical
  copy is, and a repo's `dev_docs/README.md` names its deliberate
  divergences.

## Revisit when

- Copies drift enough that syncing them costs more than a delivery mechanism
  would; the plugin could then ship the READMEs and a repo could link rather
  than copy.

## Confirmation

Nothing checks copies against the canonical ones. Review, and the `source:`
field.

## Alternatives

- **One umbrella with everything:** the first draft of this convention;
  too long, and every directory's template competed for the same reader.
