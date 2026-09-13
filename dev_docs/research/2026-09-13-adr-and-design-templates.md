---
created: 2026-09-13
question: "What do the established ADR and design-proposal formats prescribe, and which parts transfer to dev_docs/?"
feeds: ../decisions/2026-09-13-decisions-are-adrs-with-revisit-when.md
---

# ADR and design-proposal templates

## Question

What do the established formats for architecture decision records and design
proposals prescribe, and which parts transfer to a `dev_docs/` convention?

## Method

Web reads on 2026-09-13 of the primary sources for each format, plus one
distillation and one survey of industry practice:

- Nygard, [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), 2011. The origin of the ADR.
- [MADR](https://adr.github.io/madr/), the Markdown ADR template, and Zimmermann's [primer](https://ozimmer.ch/practices/2022/11/22/MADRTemplatePrimer.html) on it.
- Fuchsia's [RFC best practices](https://fuchsia.dev/fuchsia-src/contribute/governance/rfcs/best_practices), for design proposals.
- Pragmatic Engineer, [Engineering planning with RFCs, design documents and ADRs](https://newsletter.pragmaticengineer.com/p/rfcs-and-design-docs), for how companies use them.

Fetched pages were summarised by a small model; quotes below are as returned
by that summary and were not re-read against the page.

## Findings

### Nygard's ADR: four sections, immutable, superseded not edited

Title, Context ("forces at play in neutral language"), Decision ("in active
voice"), Consequences ("all resulting effects, positive and negative"), plus
a Status of `proposed`, `accepted`, `deprecated`, or `superseded`. The
immutability rule is explicit: "If a decision is reversed, we will keep the
old one around, but mark it as superseded." Files are numbered "sequentially
and monotonically. Numbers will not be reused." Target length one to two
pages.

### MADR adds options, consequences phrasing, and confirmation

Required sections: Context and Problem Statement, Considered Options,
Decision Outcome. Optional: Decision Drivers, Consequences, Confirmation,
Pros and Cons of the Options, More Information. Front matter carries `status`
(`proposed | rejected | accepted | deprecated | superseded by ADR-0123`),
`date`, and the people involved. Consequences are phrased "Good, because …"
and "Bad, because …" and "should refer to the context information and the
identified decision drivers". Confirmation exists "to remind everybody who is
involved that it is not enough to decide; design and implementation actions
are required", and documents "how the implementation of the ADR is enforced
and evaluated, for instance by way of a design/code review or a test".
Filenames are `NNNN-title-with-dashes.md`.

Neither Nygard nor MADR has a section for what would reopen the decision. The
nearest is MADR's example noting "A follow-on decision will be required".

### What makes a decision worth recording

Zimmermann's primer: an architecturally significant requirement "has a
measurable effect on a software system's architecture and quality", and the
footnoted criteria are "business value/risk, stakeholder concern, quality
level, external dependencies, cross-cutting, first-of-a-kind, past
troublemaker".

### ADR practice fails on process, not format

The search summary of practitioner reports: "Nobody decided when an ADR is
required, who reviews it, or where it lives in the daily workflow", so ADRs
become "a thing you might write if you remember". Two mitigations named: a
PR-based review of each record, and linking each record from the code it
governs, since an ADR "not referenced from the code they govern [is]
invisible at the moment they are most useful".

### Design proposals: material impact only, historical after acceptance

Fuchsia: "Your RFC should include all the details that have a material
impact on your design's acceptability, and no more", tested by whether
changing a detail would change a stakeholder's vote and whether stakeholders
should be told if implementation diverges. After acceptance, "RFCs shouldn't
change once they're accepted (beyond minor amendments)" and become historical
records. And: "Don't link to an RFC in code or documentation to explain how a
feature works."

Pragmatic Engineer does not distinguish RFC from design doc from ADR, and its
sizing rule is "For small changes: don't bother. Just make the change. For
changes that are non-trivial and have dependencies: consider writing one."
The Uber templates it reproduces are section checklists (SLAs, dependencies,
rollout, monitoring) that grew to "the ballpark of 14 pages — before being
filled in".

### What transfers, and what does not

Transfers:

- Nygard's four sections and immutability, MADR's consequences phrasing and
  Confirmation, as the decision template.
- Fuchsia's material-impact test and "don't link the RFC to explain the
  feature" as design rules.
- Pragmatic Engineer's sizing rule as the threshold for writing a design.
- The practitioner finding that format without process fails: the process
  has to say when a record is written and who reviews it.

Does not transfer:

- `NNNN-` numbering. The date prefix is already the sort key under
  `dev_docs/`, and a second sequence is a second thing to keep unique.
- MADR's people fields (`decision-makers`, `consulted`, `informed`). Single-
  owner repos; the PR carries the reviewer.
- Fuchsia's "RFC becomes a historical record". The owner's rule is the
  opposite: a design is transient and its history lives in the decisions it
  produces.
- Uber-style section checklists. Their length is the failure mode.

Added, with no source: a "Revisit when" section on every decision, because
the owner's stated purpose for a decision record is to know what would
change it, and no surveyed format has one.

## Feeds

`../decisions/2026-09-13-decisions-are-adrs-with-revisit-when.md`, and the templates in
`../decisions/README.md` and `../designs/README.md`.
