---
created: 2026-09-21
status: proposed
tracks: https://github.com/bestdan/agent-guidance/issues/62
---

# Name insider prose, then catch it on the way out

Agents write prose from inside the work, where the context is free, and ship it
to a reader for whom it is not. Two shapes recur: a body that recounts how the
work unfolded, and prose whose every clause sends the reader looking something
up. This names the failure **insider prose**, states it once in
`writing_about_code.md`, and adds four carriers that reach that file rather
than restating it. None of the new checks adds a process to a session, and none
of them blocks a write.

## What is true today

**The guidance forbids both shapes and did not prevent either.**
`writing_about_code.md` carries "Lead with the answer" and "Never build to a
conclusion"; `authoring_pull_requests.md` requires every sentence to change
what the reviewer does next. Both files were in context, loaded through the
`agent-guidance:authoring` skill, in the session that produced both examples in
[issue #62](https://github.com/bestdan/agent-guidance/issues/62). Guidance that
is in context and unfollowed is not fixed by more guidance.

**Neither shape has a name.** The two failures are one cause with two faces,
and nothing in the register says so, which leaves an author correcting a
sentence rather than a habit.

**Part of shape 2 is already written down.** The "Name things precisely"
section says a quantity carries its unit and a comparison carries its baseline.
That is exactly the complaint against `14/14 against 10/14 then 12/14`. A
second statement of it would put two versions of one rule in one file, which
`reviewing.md` calls a finding.

**Every `Write` and `Edit` already pays for a hook process.**
`hooks/comment-key-context.sh` is registered on the bare `Write|Edit` matcher
with no `if` gate, so it spawns on every write. Measured on this machine, 20
spawns each, handing the hook a 15,258-byte payload on stdin:

| Run                                     | ms per spawn |
| --------------------------------------- | ------------ |
| `bash -c true`                          | 5.02         |
| `python3 -c pass`                       | 10.11        |
| the hook, markdown path (exits early)   | 25.68        |
| the hook, `.py` path (runs its scan)    | 25.36        |

Startup is what the 25 ms buys. The hook's existing comment scan does not rise
above the noise between the last two rows, which differ by less than their
spread. The markdown row is pure waste today: the extension guard exits before
any work, so a markdown write pays 25 ms and receives nothing.

**A PR body reaches disk before it ships.** `hooks/gh-body-guard.py` denies
`--body` in favour of `--body-file`, and it runs on every `Bash` call. So a
vetting step there reads a file that already exists and spends no process of
its own.

**`scripts/prose-check.py` measures two rules over this repo's tracked
markdown**: em-dash density, which fails the build, and sentence length, which
only reports. Neither would have caught either example in the issue. The split
between failing and reporting was measured rather than preferred: 6% of
paragraphs broke the em-dash cap against 30% of sentences over the word cap.

**Writer and reviewer already share one source, and one duplication threatens
it.** `skills/authoring/SKILL.md` and `skills/reviewing/SKILL.md` both read
`writing_about_code.md` as step 1. The register therefore cannot drift between
the two roles. `reviewing.md` restating conventions in checkable form is the
one place it can, and `hooks/comment-key-context.py` hardcoding its quote of
`portable.md` is the same risk in code.

## Proposal

### The rule

`writing_about_code.md` gains one section, `## Don't write insider prose`,
placed after `## Lead with the answer`. Two rules, each with a test an author
can apply to their own draft:

- **No historical narrative.** State what is true now. Would this sentence
  exist if the work had gone right the first time? If it is there only because
  of how you got here, cut it.
- **The reader does no lookups.** Every reference resolves inside the text.
  Read each sentence cold and count what the reader would have to go find.
  Zero.

**A record whose subject is the history is exempt from the first rule.** A
decision record's Context and Alternatives, a design's "What is true today", a
research record: there the history is what the reader came for, stated as the
current subject rather than smuggled in around it. Without this the rule
condemns content `dev_docs/decisions/README.md` requires, and the five records
this design commits to writing would each break it.

It cites `## Name things precisely` for the numbers half and restates none of
it.

### One detector, three consumers

`scripts/insider_prose.py` is a pure module with no I/O and no side effects,
imported by the hook, by `prose-check.py`, and by the fixture test. What it
detects, and the scope each signal is trusted over:

**One signal, not a suite.** The module detects an unresolved `the same \d+
<noun>` over added lines, and nothing else. A firing means "go check the
antecedent", never "there is none" — the regex cannot see antecedents, so that
is the strongest claim it supports.

It strips inline-code spans before scanning, reusing the `_INLINE_CODE`
treatment `prose-check.py` already applies to both of its own rules. A
backticked literal is how markdown quotes a string, and the hook runs over
markdown in repos this plugin does not own, so a convention about fencing would
bind the one repo that needs it least. Two consequences: an `Edit`'s added text
can begin or end mid-span with one unmatched backtick, which the stripper must
survive rather than pair blindly; and bad examples inside `writing_about_code.md`
go in backticks, because the double quotes `## Name things precisely` uses for
its own examples are not stripped by anything.

The hook sees added lines, never the file around them, so an antecedent
established in unchanged text is invisible to it. `prose-check.py` reads whole
files and has the wider view. The signal's false-positive rate is therefore
worse under the hook, and the fixtures carry an edit whose antecedent sits in
unchanged context.

**Three further signals were designed and dropped before implementation**, each
on a good case it fires on: two or more bare `N/M` ratios in a sentence,
`(rule|section|step|candidate|option) \d+` in a first paragraph, and a
chronology opener in a first sentence. The ratio signal failed hardest. A
prototype run over the issue's own bad example caught `the same 14 rows` and
missed `14/14 in four passes against the harness's 10/14 then 12/14`, because
"bare" is work no regex does for free: a following-word test reads "14/14 in"
as carrying a unit and suppresses it, exactly as it reads "1/2 cup" as carrying
one and correctly suppresses that. Telling those apart needs a unit vocabulary.
The other two fire on "Step 1 installs the dependencies. Step 2 runs the tests."
and "Initially, the buffer is empty.", both ordinary technical prose.

So the mechanical tier is one regex, and shape 1 has no mechanical tier at all.
The pointer carries it.

### Carriers

**`hooks/comment-key-context.*` becomes `hooks/prose-context.*`.** It already
spawns on every `Write` and `Edit`, so both additions are in-process string
work over a few KB:

- Once per session, on the first markdown path, a pointer at the new section.
  Session-keyed marker, the mechanism `hooks/dev-docs-context.py` already uses.
- On every markdown write, the detector over added lines, reported as
  `line N:` with the offending text.

Its existing tracker-key check is untouched, including the markdown exclusion,
because the two checks disagree about markdown on purpose.

**`hooks/gh-body-guard.py` gains a body vet.** It resolves `--body-file` to a
path already, so it runs the module against that file and returns
`additionalContext`. It allows the command.

**`reviewing.md` gains a pointer, not a restatement.** One line under `## What
a review checks` naming the section and the two shapes as checkable, with the
rule's text staying in `writing_about_code.md`.

**`scripts/prose-check.py` gains the module's rules** over this repo's tracked
markdown.

### The hook quotes the file at run time

The hook reads the section out of `writing_about_code.md` at run time through
`GUIDANCE_ROOT`. Only `hooks/dev-docs-context.sh` exports that variable today;
`hooks/comment-key-context.sh` and `hooks/gh-body-guard.sh` each run `python3`
with `PAYLOAD` alone, so both wrappers gain it as part of this change.

No carrier holds a copy of the rule's text. The reviewer reaches the same bytes
by a different route: `skills/reviewing/SKILL.md` reads `writing_about_code.md`
as step 1, before `reviewing.md`. That is what makes a prose-equality test
unnecessary, which matters because `skills.test.sh` states its scope as the
wiring and never the prose.

`prose-check.py` and the fixture test quote nothing. They share the detector
module, so drift between those two is a module concern rather than a prose one.

**The read fails closed.** The extraction requires exactly one matching heading.
On any failure — no `GUIDANCE_ROOT`, a moved file, a renamed heading, more than
one match — the hook emits `additionalContext` naming the miss instead of
falling through silently. A silent failure would remove the warning for every
installed user with nothing reporting it. `skills.test.sh` gains an assertion
that the section resolves, which stays inside its wiring-not-prose scope.

## Decisions

### The rule lives in `writing_about_code.md` alone

Both skills already read that file first, so a rule stated there reaches the
writer and the reviewer from one source. The alternative was a fourth prose
file linked from three places. Rejected: the failure diagnosed in issue #62 is
not-re-reading, and a file one link further away is read less rather than more.

### Every carrier quotes the file at run time

`hooks/comment-key-context.py` holds a hardcoded quote of `portable.md`, and a
second hook doing the same would make drift the default. The hook reads the
section instead. The alternative was a test asserting the same sentence appears
in two files. Rejected: it would be the first assertion in this suite about
prose rather than wiring.

### The checks ride the processes that already exist

Both additions land inside hook scripts that already spawn, so no new process
is created and the added cost is the scan alone: **0.44 ms** at process level
and 0.69 ms measured in-process over 200 repetitions, against the same
15,258-byte markdown payload. That is under 3% of the 25 ms the spawn already
costs.

The alternatives were a new `PreToolUse` handler gated on `Write(**/*.md)`,
which pays a fresh 25 ms per markdown write to do 0.44 ms of work, and a `Stop`
hook reading `transcript_path`, which caps the cost at one process per turn but
fires after the turn, too late for a `gh pr create` in the same turn.

### The detector is one module, not three implementations

The hook, `prose-check.py` and the fixture test import `scripts/insider_prose.py`.
No `hooks/*.py` in this repo imports local code today, so the wrapper adds the
module's directory to `sys.path`. The alternative was a copy of the patterns in
each consumer, which drifts with nothing reporting it.

### Fixtures precede the detector

`insider-prose.test.py` carries four bad cases and three good ones before any
pattern is written. Bad-1 and bad-2 are the issue's two examples verbatim;
bad-3 is a `SKILL.md` opener recounting its own design history; bad-4 is a
decision record pointing at "the other two" with no antecedent. The three good
cases are rewrites of bad-1, bad-2 and bad-3, and they are load-bearing: a
detector that fires on a correct rewrite is worse than one that misses.
Otherwise the check gets built around what is easy to detect.

### Jev is the instrument for one measurement, never a shipped dependency

Jev is TypeSafe's hosted model, which takes a passage plus a yes/no,
multiple-choice or rating question and returns a typed answer with
probabilities. "Does this passage contain historical narrative" is a yes/no
judged from text already in hand, and `workflow-skills`
`dev_docs/typed-model-calls.md` admits exactly that to a typed call: compute it
in code when you can, use a typed call for a fixed-set or yes/no judgment over
text you already have, and reason it out yourself when the job needs steps or
fetching. Shape 1 is the one thing here regex cannot reach.

It is still wrong in both shipped sites. That file bars a network call from the
blocking gate, which must stay hermetic and offline; and it permits a key
requirement only as a fast path that degrades when the key is absent, which a
hook running for every installed user on every write cannot be.

So it runs once, offline, over the fixtures, as a research record's artifact
under `references/`. That file sets the comparison: not accuracy against ground
truth, but whether the typed call beats what is done today, which here is the
model re-reading the section after the pointer. It also requires more than one
pass, because a margin measured there moved threefold across four runs of an
identical prompt. The three measurements that file records each ended in a
decision not to adopt what they measured, so the pointer is the likely winner
on cost. The shipped path is unchanged either way
and the result is a number instead of a guess.

### The hook warns and allows

The `--body` denial in `gh-body-guard.py` stays a denial, because it is a
safety guard, and
`dev_docs/decisions/2026-09-19-a-safety-guard-denies-and-has-no-hatch.md` is
why. The insider-prose check is style, so it returns `additionalContext` and
allows. A style check that denies is eventually wrong with no way past it, and
it would deny the write that fixes a violation.

### The rule ships as failing, because this corpus cannot decide it

Measured over all 46 tracked `*.md` files, at the scope each was designed for,
all four candidate signals return zero hits. The corpus therefore cannot play
the part the em-dash precedent played. That split had spread to read, 6% of
paragraphs against 30% of sentences, and a rule most of the corpus already broke
was the thing worth not enforcing.

Here nothing breaks, so the surviving rule ships as failing: a check that fires
zero times today costs nothing to enforce, and the first firing is a finding
rather than a backlog.

A zero-hit corpus is also why the fixtures decide which signals exist. Three of
the four were dropped on good cases the corpus could never have surfaced.

## Not decided here

- Whether the surviving signal earns its place once the fixtures run. It is
  dropped rather than tuned if it fires on a good case, and the design then
  keeps the rule and the pointer with no mechanical tier at all.
- Whether Jev is adopted for shape 1. The probe answers it, and a win would
  need a degrade-to-pointer path before anything shipped.
- Whether commit bodies and status updates get triggers of their own. The rule
  reaches them through the register; only markdown writes and PR bodies get a
  mechanical check here. Decision and research records are markdown writes, so
  the hook does see them — the genre exemption above is what keeps it from
  reporting their required history.
- What the pointer costs in tokens against what it saves. Worth measuring after
  it exists.

## Graduation

Decision records to write on landing. Three decisions above produce no record
of their own: fixtures-before-detector is this repo's normal practice, the
warn-and-allow split is already recorded in
`dev_docs/decisions/2026-09-19-a-safety-guard-denies-and-has-no-hatch.md`, and
run-time quoting shares the first record below with the one-file decision.

- The rule lives in one file and every carrier quotes it at run time, rather
  than holding a copy.
- A check rides an existing hook process rather than adding a handler, with the
  25 ms spawn against 0.44 ms scan measurement behind it.
- The detector is one module with three consumers, and why it does not live
  beside the hook.
- Jev is an instrument for a measurement, not a dependency a carrier may hold.
- Three of four candidate signals were dropped before implementation, and what
  it cost to learn that a regex cannot read "bare".

Conventions that receive the guidance:

- `writing_about_code.md`: the `## Don't write insider prose` section.
- `reviewing.md`: the pointer under `## What a review checks`.
- `dev_docs/research/2026-09-21-insider-prose-detection/`: the fixtures, the
  probe, and the numbers.

Delivery is two PRs. The first carries the rule, the `reviewing.md` pointer,
the fixtures, `scripts/insider_prose.py`, and `prose-check.py` gaining the rule
with the corpus measurement behind it. The second carries the two hook
carriers: the `prose-context` rename and the `gh-body-guard.py` vet, with the
`GUIDANCE_ROOT` export both wrappers need.

The pointer ships with the rule it points at, so no third PR is left with
anything to carry.
