---
created: 2026-09-13
purpose: conventions for this directory
source: bestdan/agent-guidance dev_docs/research/README.md
---

# Research

A research record answers a question with evidence gathered at a point in
time: a survey of how something is done today, a comparison of options, a
measurement. It feeds a design or a decision and is cited from there, so the
design stays short and the evidence stays checkable.

The record is what was found, not what to do about it. A recommendation
belongs in the design or decision that cites the research, so the evidence
can be re-read without the conclusion colouring it.

## When to write one

When a design or decision would otherwise carry more than a paragraph of
evidence, or when the gathering was expensive enough that the next person
should not repeat it. A quick fact goes in the design or the PR body.

## What is in one

- **Question.** What the research set out to answer, in one sentence.
- **Method.** What was examined and how: which repos, which sources, which
  commands, on what date. Enough that the result can be reproduced or its
  staleness judged.
- **Findings.** What was found, with the evidence beside each finding: a
  path, a quote, a number. Separate what was verified from what was inferred.
- **Feeds.** The design or decision this research supports, once it exists.

## Naming and front matter

`YYYY-MM-DD-<slug>.md`, kebab-case. The date is when the research was done
and matches `created`. A research record is a snapshot. `feeds` is the one
field set after writing, when the design or decision it supports exists;
nothing else changes, and research done again later is a new record.

A record that carries artifacts — the script that measured something, the
capture it read, the numbers it produced — becomes `YYYY-MM-DD-<slug>/` with
the record as its `README.md` and the artifacts under `references/`. The rules
above are unchanged; the date moves to the directory. `dev_docs_layout.md` at
the plugin root has the shape and what does not belong there.

The fields are unchanged; a relative path inside one is not. It resolves from
a file one level deeper, so the template's `feeds: ../designs/<name>.md`
becomes `../../designs/<name>.md`.

```yaml
---
created: 2026-09-13
question: "what the record answers, in one sentence"
feeds: ../designs/2026-09-13-some-design.md # once it exists
---
```

## Research spikes

The `workflow-skills` `research-spike` skill scaffolds
`dev_docs/research/<project>/` for a long-running spike with its own ledger of
questions and obligations. Those subdirectories are the skill's, and its
`README` conventions do not apply inside them. A spike and the flat records
here coexist: the spike's questions can cite records, and a record can be the
answer that closes one.

## Template

```markdown
---
created: YYYY-MM-DD
question: ""
feeds:
---

# <Title naming the question>

## Question

<One sentence.>

## Method

<What was examined, how, when.>

## Findings

### <Finding>

<What was found, with the evidence beside it.>

## Feeds

<The design or decision this supports.>
```
