# Writing and Talking About Code

This governs how you communicate about code and technical topics, in every setting: answering a question in chat,
explaining how a system works, a design doc, a commit body, a review comment, a PR description, an incident writeup, a
status update.

It is about the communication, not the work. It does not govern the code, the identifiers, the file paths, or quoted
output.

Code comments are in scope, and they are the highest-stakes case. A comment is prose about code written for a reader,
so every rule here governs it — and unlike a PR description, it ships with the code and is read by everyone who touches
the line afterwards. How much comment a change should carry is set by the Code section of `portable.md`.

## Lead with the answer

Bottom line up front. The first sentence carries the answer, the recommendation, or the verdict. Evidence, detail,
caveats, and alternatives come below it, in that order. A reader who stops after two sentences has still got what they
came for.

Never build to a conclusion. An explanation is not a story, and a reader who has to reach the end to learn whether the
answer was yes has been made to do your work.

## Don't write insider prose

You write from inside the work, where the context is free. It is not free where it is read. Two shapes follow from
that, and they are one habit with two faces.

- **No historical narrative.** State what is true now. Would this sentence exist if the work had gone right the first
  time? If it is there only because of how you got here — a candidate that lost, an approach you abandoned, a section
  number from your own process — cut it. The reader is deciding about the thing, not auditing its making.
- **Leave no reference dangling.** A demonstrative needs its antecedent in the same text: `the same 14 rows` as what,
  `the other two` being which, `rule 1` of what. Read each sentence cold and count what the reader has to reconstruct
  from context you never gave them. Zero.

A deliberate citation is the opposite of a dangling reference, and `## Say what you know` requires it: a `file:line`, a
command with its output, an issue named as an issue. Those send the reader somewhere on purpose. For the numbers half
of the second rule — a quantity carrying its unit, a comparison carrying its baseline — see `## Name things precisely`,
which states it already.

**A record whose subject is the history is exempt from the first rule.** A decision record's context and alternatives, a
design's account of what is true today, a research record: there the history is what the reader came for, stated as the
current subject rather than smuggled in around something else.

## Say what you know, and say how you know it

- A claim about behavior carries its evidence: a `file:line`, a command and the output it produced, a test that fails.
  An assertion the reader cannot check costs a round trip to establish.
- Separate what you verified from what you inferred. "`parse_body` returns `None` here — I ran it against the fixture"
  is a different claim from "`parse_body` probably returns `None` here", and collapsing the two is how a guess gets
  acted on.
- Say what you do not know. Absence claims — "there is no such setting", "nothing calls this" — are the ones most often
  wrong, because looking cannot distinguish "not there" from "not where I looked". Verify one or qualify it.
- Never invent a rationale. If nothing in the code, the history, or the ticket says why something is the way it is, say
  that. A confident wrong "why" is worse than a missing one: it survives into the archaeology and nobody knows to doubt
  it.

## Explain the non-obvious, not the obvious

Skip whatever a reader fluent in the language or framework reads at a glance. Spend the words on the trade-off, the
workaround, the constraint that is not visible in the code, the reason for this shape instead of the obvious one. That
is the highest-value content in anything written about code, and it is the only content the code cannot supply itself.

## Code comments

Everything above applies. Two rules bind hardest inside a source file:

- **A comment says the thing itself.** No ticket key, no PR number, no "see the commit message". A reader with no
  tracker access and no network has the whole explanation, or the comment has failed at the one job a comment has. A
  `TODO` is the exception, because there the key names outstanding work rather than citing a source.
- **A comment does not repeat the commit body or the PR description.** Those carry the story of the change; a comment
  carries the constraint that outlives it. A comment that has started restating the PR is telling you its content
  belongs to the PR alone.

"Explain the non-obvious, not the obvious" does the rest. A comment that survives both rules is short because little is
left to say, not because a line count stopped it.

## Name things precisely

Refer to code by its real identifier and location — `parse_body` in `src/parser.py:87`, not "the parsing helper". Use
one name for one thing throughout; a synonym introduced for variety reads as a second thing.

Name a symbol only when the sentence is about that symbol. A list of the symbols you touched is an inventory, not an
explanation.

A bare number names nothing. Say what it is: PR #543, issue #534, commit `26a4361`, line 87 of the fixture. The case that
actually misleads is two of them in one sentence — "running the gate on 543 and dispatching #534" reads as one kind of
thing twice, and `#` does not distinguish a PR from an issue. A quantity carries its unit, and a comparison carries its
baseline: "2.1s at p99", not "2.1"; "faster than the loop it replaces", not "faster".

## A command's output is not a result

Report the outcome of the task you were asked to do. A command run along the way may print state
that has nothing to do with that task — don't turn it into findings, a to-do list, or an offer of
further work.

## Report a problem with its consequence

A defect stated alone gets argued. A defect stated with what it costs gets fixed. "This reads the file on every request"
is the first kind. "This reads the file on every request, so a 5k-row CSV costs a disk read per page view" is the
second.

The same holds for a risk, a limitation, or a thing you did not do: say what follows from it.

## Length

Write the shortest text that leaves the reader with no question you could have answered. A section that adds nothing is
omitted, not padded; a heading kept with filler under it is worse than no heading.

Length is usually misplaced content, not excess content. The fix is to move the detail — below the bottom line, into the
document that owns it, or into a follow-up — not to compress everything evenly until all of it is hard to read.

## Voice

- No narrator voice — "This PR replaces...", "In this change we...", "Let me explain...", "First, some background...".
  Start with the point.
- No labeled callouts — "Key change:", "Note:", "Worth a look:", "One deliberate asymmetry:". Make the observation
  without announcing it.
- No empty intensifiers — "robust", "seamless", "comprehensive", "genuinely", "leverage".
- At most one em-dash interruption per paragraph (a matched pair is one), and no rule-of-three parallelism ("filter,
  cast, and reuse").
- No rhetorical question standing in for a statement, and no praise padding to soften a finding. Both make the reader
  work out what you actually meant.

## Feedback on someone else's code

Everything above applies. Reviewing adds three rules:

- **One point per comment.** A comment carrying three findings gets one reply, and two of them are lost.
- **Say whether it blocks.** An unlabelled suggestion reads as blocking to a cautious author and as optional to a
  confident one. Prefix the ones that do not block (`nit:`, `optional:`).
- **Comment on the code, not the author.** "This allocates per row" and "you allocate per row" get read differently and
  argued differently.

## Anything public is permanent

On a public repo, a mailing list, or an open tracker, what you write outlives the thread and is indexed. Strip internal
URLs, employee and customer names, and team references, and say the same thing in generic terms.
