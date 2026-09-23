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
`writing_about_code.md`, and adds three carriers that reach that file rather
than restating it. The checks register no new hook and block no write; what
they cost is an interpreter start on markdown writes that today stop at the
shell. The check that runs at PR time is three lines in a guard that already
exists, not a fourth carrier here.

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

**Every `Write` and `Edit` spawns a hook, but most stop at the shell.**
`hooks/comment-key-context.sh` is registered on the bare `Write|Edit` matcher
with no `if` gate, so `bash` starts on every write. A `case` test on the raw
payload then exits before `python3` unless the payload carries an uppercase
tracker-key shape, which an ordinary markdown write does not. Measured on this
machine, 20 spawns each:

| Run                                            | ms per spawn |
| ---------------------------------------------- | ------------ |
| `bash -c true`                                 | 5.02         |
| `python3 -c pass`                              | 10.11        |
| the hook, markdown write the prefilter rejects | 10.70        |
| the hook, payload the prefilter admits         | 24.59        |

The process is half paid for, not paid for. `bash` is already spent on every
write; the interpreter is not, and the interpreter is what any new check needs.

Measuring this is easy to get wrong in one direction. A payload that happens to
satisfy the prefilter prices the admitted path, which makes the scan look free
against a process that was going to start anyway. Price the rejected path, and
the interpreter is the cost.

**A PR body reaches disk before it ships.** `hooks/gh-body-guard.py` denies
`--body` in favour of `--body-file`, so a body exists as a file, normally
written by a `Write` to a `.md` path before any `gh` command runs. That write
is what a markdown carrier sees, and it sees it while no PR exists yet.

**A PR-body guard already exists, outside this plugin.**
`bestdan/dotfiles` `agents/guard_pr_body.py` is a `PreToolUse` guard that
denies a `gh pr create` or `gh pr edit` whose title or body breaks the
authoring guideline. It enforces the word ceiling, a banned-phrase list,
narrator openers and the title grammar, across the `gh` flags and the GitHub
MCP tools that would otherwise route around it. It strips fenced blocks,
inline code and HTML comments before measuring anything, and a body carrying
`<!-- pr-guard: allow -->` on a line of its own passes untouched.

It is machine-local, so this plugin cannot assume it exists, and it embeds its
rules rather than reading them from here, deliberately, so that it needs no
path to the plugin. Its own diagnosis of why it exists is this design's:
a prose rule alone loses to an agent's instinct to be thorough, and the failure
stays invisible until a human opens the PR and stops reading.

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
- **The reader resolves no references you left dangling.** A demonstrative
  needs its antecedent in the same text: "the same 14 rows" as what, "the other
  two" being which. Read each sentence cold and count what the reader has to
  reconstruct from context you did not give them. Zero. A deliberate citation
  is the opposite of this and is required elsewhere in this file: a `file:line`,
  a command with its output, an issue number named as an issue. Those send the
  reader somewhere on purpose, and `## Say what you know` asks for them.

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
imported by the hook, by `prose-check.py`, and by the fixture test.

**One signal, not a suite.** The module detects an unresolved `the same \d+
<noun>` over added lines, and nothing else. A firing means "go check the
antecedent", never "there is none" — the regex cannot see antecedents, so that
is the strongest claim it supports.

It strips inline-code spans before scanning, reusing the `_INLINE_CODE`
treatment `prose-check.py` already applies to both of its own rules. A
backticked literal is how markdown quotes a string, and the hook runs over
markdown in repos this plugin does not own, so a convention about fencing would
bind the one repo that needs it least. Under `prose-check.py`, which holds the
whole file, the stripping widens to fences and HTML comments as well; the hook
cannot follow it there, for the reason the decision below gives. Two
consequences: an `Edit`'s added text
can begin or end mid-span with one unmatched backtick, which the stripper must
survive rather than pair blindly; and bad examples inside `writing_about_code.md`
go in backticks, because the double quotes `## Name things precisely` uses for
its own examples are not stripped by anything.

Both consumers run the same signal and report the same warning. What differs is
what each can feed it: the hook has added lines, `prose-check.py` has whole
files, and each strips what its input lets it strip. Neither resolves an
antecedent, so neither can tell a dangling reference from a satisfied one, and
the wider input buys no better verdict. The difference is what the author has
in front of them when the warning arrives, not how often it is wrong.

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

Two gates stand between the wrapper and that code, and both move. The shell
`case` at `hooks/comment-key-context.sh:75` exits before `python3` on any
payload without a tracker-key shape, so it gains a second arm admitting a
markdown `file_path`. The `PROSE` extension exit at
`hooks/comment-key-context.py:34` then returns early on exactly the files the
new check wants, so it becomes a branch into the detector rather than a
`sys.exit(0)`. The tracker-key check's own behaviour is unchanged; what changes
is that markdown no longer means "nothing to do here".

**`hooks/gh-body-guard.py` gains nothing.** A PR-time carrier in this plugin
was designed and dropped; the decision below says why, and where the PR-time
check goes instead.

**`reviewing.md` gains a pointer, not a restatement.** One line under `## What
a review checks` naming the section and the two shapes as checkable, with the
rule's text staying in `writing_about_code.md`.

**`scripts/prose-check.py` gains the module's rules** over this repo's tracked
markdown.

### The hook quotes the file at run time

The hook reads the section out of `writing_about_code.md` at run time through
`GUIDANCE_ROOT`. Only `hooks/dev-docs-context.sh` exports that variable today;
`hooks/comment-key-context.sh` runs `python3` with `PAYLOAD` alone, so that
wrapper gains it as part of this change.

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

### The hook carrier quotes the file at run time

`hooks/comment-key-context.py` holds a hardcoded quote of `portable.md`, and a
second such quote beside it would make drift the default. The hook reads the
section instead. The alternative was a test asserting the same sentence appears
in two files. Rejected: it would be the first assertion in this suite about
prose rather than wiring.

### The checks ride the processes that already exist

Both additions land inside hook scripts whose `bash` already runs, so what the
change buys is an interpreter, not a process. Measured per markdown write, 20
spawns each:

| Carrier                                         | ms per markdown write |
| ----------------------------------------------- | --------------------- |
| today, the prefilter rejects it                 | 10.70                 |
| widen the prefilter, one process does both jobs | 24.59                 |
| a separate handler gated on `Write(**/*.md)`    | 38.89                 |

The scan itself is 0.44 ms of that, so it is not what anything here costs. The
gated handler is the expensive option rather than the clean one, because it
does not replace the existing hook: `comment-key-context.sh` still spawns on
every write, so its 10.70 ms is paid again underneath the new handler's own
start-up. Widening the prefilter is 14 ms cheaper for the same work.

The remaining alternative was a `Stop` hook reading `transcript_path`, which
caps the cost at one process per turn but fires after the turn, too late for a
`gh pr create` in the same turn.

### The detector is one module, not three implementations

The hook, `prose-check.py` and the fixture test import `scripts/insider_prose.py`.
No `hooks/*.py` in this repo imports local code today, so the wrapper adds the
module's directory to `sys.path`. The alternative was a copy of the patterns in
each consumer, which drifts with nothing reporting it.

### Fixtures precede the detector

`insider-prose.test.py` carries four bad cases and three good ones before any
pattern is written, reached by a one-line `insider-prose.test.sh` beside it.
The wrapper is not decoration: `scripts/run-tests.sh` discovers suites with
`git ls-files '*.test.sh'`, so a bare `.test.py` never runs in CI.
`gh-body-guard.test.sh` is the same pairing already in the repo. Bad-1 and bad-2 are the issue's two examples verbatim;
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

So it runs once, out of band and online, over the fixtures, as a research
record's artifact under `references/`. What stays offline is the blocking gate
and the artifact the probe leaves behind, never the probe itself. That file sets the comparison: not accuracy against ground
truth, but whether the typed call beats what is done today, which here is the
model re-reading the section after the pointer. It also requires more than one
pass, because a margin measured there moved threefold across four runs of an
identical prompt. The three measurements that file records each ended in a
decision not to adopt what they measured, so the pointer is the likely winner
on cost. The shipped path is unchanged either way
and the result is a number instead of a guess.

### The markdown carrier warns and allows

It returns `additionalContext` and never denies. A hook that denied a markdown
write would deny the write that fixes a violation, which is the argument
`dev_docs/decisions/2026-09-16-dev-docs-hook-never-denies-the-write.md` already
makes for the layout pointer.

`gh-body-guard.py`'s `--body` denial is untouched and stays a denial, being a
safety guard rather than a style check, per
`dev_docs/decisions/2026-09-19-a-safety-guard-denies-and-has-no-hatch.md`.

Denying is not ruled out everywhere, only here. The PR-time check denies, in
the guard that can, with an escape marker.

### What `guard_pr_body.py` settles, and what it reopens

That guard is older and in daily use, and three of its choices bear on this
design. Each is taken deliberately here rather than by default.

- **It strips fenced blocks, inline code and HTML comments before measuring;
  the detector strips less.** Not a narrower ambition, a narrower input. The
  guard holds a whole body, so it can pair a fence and know what sits inside
  it. The hook holds added lines, which carry no fence state at all: an added
  line inside a fenced block is indistinguishable from one outside it, and
  `prose-check.py:50-67` gets that right only by streaming the whole file. So
  the hook strips the spans it can pair inside the added lines, leaving an
  unmatched backtick's span unstripped rather than mispairing it, and
  `prose-check.py` gets the full treatment because it has the document. A
  single-line HTML comment is strippable from added lines too; a multi-line one
  is not, and is left.
- **It embeds its rules; the hook carrier here quotes `writing_about_code.md`
  at run time.** Both fit their carrier. The guard must work on a machine where
  this plugin is absent, so embedding is its only option; a plugin hook ships
  beside the file it quotes, so quoting costs nothing and removes the drift the
  guard has to accept.
- **It denies, with an escape marker; this plugin's carrier warns.** Not
  because one enforces facts and the other judgment. The guard's word ceiling
  and narrator openers are heuristics too, and it denies on them. The
  difference is where each sits: a hook that warns cannot stop anything, and
  the plugin chose that shape for a signal it ships to repos it does not own.

### The PR-time check is one tuple in that guard, not a carrier here

A `PreToolUse` hook that allows does not gate. Verified: a write to this design
fired `dev-docs-context`, the guidance arrived, and the file was created
anyway. So a plugin carrier on `gh pr create` could only warn after the PR was
published, and the `gh pr edit` that follows is the best it could buy.

The markdown carrier already covers the path that matters. A PR body is
normally written to a `.md` file first, which warns while the body is still
local and no PR exists, so issue #62's "before the PR opens" is met there
rather than at `gh pr create`.

What the plugin cannot do, `guard_pr_body.py` can: it denies before
publication, and its `BANNED` is a list of `(regex, why)` pairs, so the
dangling-reference signal is three lines. That is the PR-time check.

The cost is honest and worth stating. `guard_pr_body.py` is machine-local, so
a PR body composed by a heredoc, on a machine without it, in a session that
wrote no markdown, is not checked at all. That case buys a portable carrier
whose own description would have to be "warns after publishing", and it is not
worth one.

### The rule reports and never fails, because it cannot decide a defect

`prose-check.py` already splits its two rules this way, and the line it draws
is precision rather than importance. The em-dash cap fails the build because a
paragraph either carries more than one interruption or it does not. Sentence
length only reports, because a long sentence is a candidate and not a verdict.

This signal is the second kind, and its own specification says so: it can claim
"go check the antecedent" and never "there is none". Measured on the prototype,
`The baseline covered 14 rows. The candidate covered the same 14 rows.` and
`On the same 14 rows the typed call scored well.` produce the identical finding.
The first resolves its reference and the second does not, and nothing in the
regex separates them. A check that cannot tell those apart cannot fail a build
without failing correct prose.

The corpus measurement does not rescue it. All four candidate signals return
zero hits across the 46 tracked `*.md` files, so nothing existing breaks — but
that is a fact about today's text, not about the check's precision on text
someone writes next week, which is what enforcement would rest on.

A zero-hit corpus is also why the fixtures decide which signals exist. Three of
the four were dropped on good cases the corpus could never have surfaced.

## Not decided here

- Whether the surviving signal earns its place once the fixtures run. It is
  dropped rather than tuned if it fires on a good case, and the design then
  keeps the rule and the pointer with no mechanical tier at all.
- Whether Jev is adopted for shape 1. The probe answers it, and a win would
  need a degrade-to-pointer path before anything shipped.
- Whether commit bodies and status updates get triggers of their own. The rule
  reaches them through the register; only markdown writes get a mechanical
  check in this plugin. Decision and research records are markdown writes, so
  the hook does see them, and the one thing it can report there is the shape-2
  regex, which the genre exemption does not govern. Nothing mechanical reports
  historical narrative in the first place: the exemption is addressed to the
  author and the reviewer reading the rule, not to a carrier.
- What the pointer costs in tokens against what it saves. Worth measuring after
  it exists.

## Graduation

Decision records to write on landing. Three decisions above produce no record
of their own: fixtures-before-detector is this repo's normal practice, the
warn-and-allow split is already recorded in
`dev_docs/decisions/2026-09-19-a-safety-guard-denies-and-has-no-hatch.md`, and
run-time quoting shares the first record below with the one-file decision.

- The rule lives in one file and the hook carrier quotes it at run time, rather
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
with the corpus measurement behind it. The second carries the `prose-context`
rename, with the prefilter widening it needs and the `GUIDANCE_ROOT` export its
wrapper needs.

The PR-time check is a third change, in `bestdan/dotfiles` rather than here:
one `(regex, why)` tuple in `guard_pr_body.py`'s `BANNED`, with a case in its
own suite. It is independent of both PRs above and lands whenever.

The rename reaches past the two files. `hooks/hooks.json`, `README.md`,
`dev_docs/conventions.md` and the suite file `comment-key-context.test.sh` all
name the old path, and an unrenamed `hooks.json` entry is a hook that silently
stops running. Decision records naming the old path stay as they are, being
records of when it was true.

The pointer ships with the rule it points at, so no third PR is left with
anything to carry.
