# Review and authoring conventions

How the reviewing and PR-authoring conventions are stored, delivered, and
enforced. This is the live description, and it states what to do without
sending the reader anywhere. The records under `decisions/` carry the reasoning
behind each choice and the evidence that would reopen it. They are cited where
they apply, and none has to be read to act on this file.

## Architecture

Three content files at the plugin root carry the rules. They are the content
layer, not the interface.

| File                         | Carries                                                                                  | Serves     |
| ---------------------------- | ---------------------------------------------------------------------------------------- | ---------- |
| `writing_about_code.md`      | the register for any prose about code: lead with the answer, evidence, naming, voice     | both verbs |
| `authoring_pull_requests.md` | what a PR adds: the body budget, the shape, body-matches-diff, template precedence       | authoring  |
| `reviewing.md`               | what a review checks, the blocking decoration, the conventional-comment label, anchoring | reviewing  |

Two skills sit on top, split by verb. `skills/authoring` fires at PR time and
reads the shared file then `authoring_pull_requests.md`; `skills/reviewing`
fires when a review starts and reads the shared file then `reviewing.md`.
Neither loads at session start, and neither reads the other verb's file. Keep
the split when adding a rule. A skill's content is charged to the context window
every time it fires. Each verb should pay for its half alone, so a review never
loads the PR-body grammar (`decisions/2026-09-12-two-skills-by-verb.md`).

Three carriers deliver the content, and none commits anything to a consumer
repo:

1. **The skills**, on Claude Code, from the installed plugin.
2. **co-review's assembled `<INPUT>`**, in `bestdan/workflow-skills`.
   `scripts/coreview-conventions.sh` resolves the installed plugin through
   `scripts/agent-guidance-dir.sh` and prints the paths of
   `writing_about_code.md` then `reviewing.md`. The dispatcher pastes those
   paths into the `cat` that assembles `<INPUT>`, so every reviewer reads
   rubric, then conventions, then requests, then diff.
3. **The Codex pointer.** `sync_codex.sh` in `bestdan/dotfiles` concatenates the
   installed plugin's `portable.md` into `~/.codex/AGENTS.md`, and the two
   `Rules` bullets in `portable.md` tell any harness without skills to read the
   files from the plugin root.

Carrier 2 is the load-bearing one for reviewing. It is the only carrier that
reads the files itself rather than instructing a model to read them, and the
only one that reaches all five external reviewers, four of which are cut off
from repo context by mechanism. Keep it failing soft and loud. Resolve the paths
once before dispatch, so the reviewer command tails stay byte-identical and the
exact-match allow rules still match. A missing installed copy exits `3`, and the
dispatcher drops the segment and records `conventions: not attached` on the run
summary. Exit `1` means `AGENT_GUIDANCE_DIR` is set but wrong, and it is
surfaced rather than swallowed
(`decisions/2026-09-12-co-review-carrier-is-the-assembled-file.md`).

`portable.md` also carries the two rules every session needs without loading a
skill: the PR title grammar in its `Git:` bullet, and `## Precedence`.

A fourth carrier shape exists, fires on a tool call rather than being offered to
the model, and has its own section below.

## Who resolves the plugin root

Carrier 3 names three files by filename alone, so something has to say which
directory holds them. `inject.sh` does it: the `## Provenance of this guidance`
section it appends to every payload names the directory it delivered from,
and `portable.md` defines the plugin root as that directory. Carriers 1 and 2
never need it — the skills expand `${CLAUDE_PLUGIN_ROOT}` and co-review pastes
absolute paths before dispatch.

That covers both hook registrations, `hooks/hooks.json` and `codex/hooks.json`.
It does not cover the other Codex route: `sync_codex.sh` runs `cat` over
`portable.md` itself rather than the hook, so the generated `~/.codex/AGENTS.md`
carries no provenance section and no root. The script resolves the directory
already, in `_codex_guidance_msg`, so closing the gap is a `dotfiles` change of
one line. Until it lands, the bullets fail loud rather than silent: with no
provenance section they say to ask for the path, not to write without the
conventions.

## Hooks

A `PreToolUse` hook is the carrier the harness fires itself. It fires on a tool
call, before the call runs, rather than at session start or when a model loads
a skill. Two are registered: `hooks/dev-docs-context.sh` names `dev_docs_layout.md` before a
write under `dev_docs/`, and `hooks/gh-body-guard.sh` refuses a `gh` command
whose free-text flag would run a shell substitution.

The route is Claude Code only, because Codex registers `SessionStart` alone. A
hook is therefore an upgrade on a route both harnesses have, never the only
route. The `dev_docs/` layout also reaches Codex, through the `Writing anything
under dev_docs/` bullet in `portable.md`. The `gh` rule reaches it as prose with
nothing behind it.

**A hook when the trigger is mechanical; a skill when it is a judgment.** A
path either has a `dev_docs` segment or it does not, and the harness can decide
that without the model. The guidance then arrives in front of the write, rather
than depending on the model to notice a bullet. Do not reach for a skill's
`paths:` front matter to express the same condition. The field is inert on a
skill a plugin ships. Where it works at all, it activates after the write, which
is the wrong side of the event
(`decisions/2026-09-16-conditional-guidance-rides-a-pretooluse-hook.md`).

**A hook carrying guidance advises; a hook enforcing a safety rule denies.**
The test is whether a reader could want the guarded behaviour. If yes, the rule
is guidance: return `additionalContext`, set no permission decision, and exit 0
on every path, including a payload the script cannot parse. Then a bug in the
script costs a missing pointer rather than a session that cannot write files.
The write that fixes a violation is not blocked alongside the violation
(`decisions/2026-09-16-dev-docs-hook-never-denies-the-write.md`). If no, return
`permissionDecision: deny` with a reason naming the safe spelling, and ship no
override marker. A marker is a way to request the one behaviour the rule exists
to prevent (`decisions/2026-09-19-a-safety-guard-denies-and-has-no-hatch.md`).
Name a remedy that does not expire. The `gh` guard names `--body-file` rather
than single-quoting, because a body is prose and will eventually contain an
apostrophe.

**A guidance hook names the file and stops.** It never inlines the content.
`dev_docs_layout.md` is about 2,406 tokens, and it is out of the always-on
payload because most sessions never need it. Inlining it one write at a time
reintroduces exactly that cost. A second copy also drifts, and
`scripts/dev-docs-layout.py` names the same file in its own failure output, so
one text has to be the text
(`decisions/2026-09-16-dev-docs-hook-emits-a-pointer.md`).

**A pointer is emitted once per session, not once per write.** The script writes
a zero-byte marker keyed on the payload's `session_id`, and speaks only when the
marker is absent. A plan that writes nine records then pays for the paragraph
once. The marker goes under `/tmp/claude` rather than the payload's
`scratchpad_dir`, which the live probe did not receive. When the marker
directory cannot be written, emit anyway: repetition is a cheaper failure than
silence (`decisions/2026-09-16-dev-docs-pointer-fires-once-per-session.md`).

**Narrow the dispatch in two layers and keep both.** The handler's `if` field
decides whether the process starts, and the script's own test decides whether
it speaks. Measured on 2.1.274, three writes under `src/` produced three spawns
on the bare matcher and none with `if` set. The tested layer is what survives a
config edit, so the script still says nothing outside `dev_docs/` if the `if`
is dropped or loosened. Two details are easy to get wrong. The rule needs a
leading `**/`, because `Write(dev_docs/**)` anchors at the project root and
misses `packages/x/dev_docs/x.md`. The script tests path segments rather than a
substring, so editing `dev_docs_layout.md` at a repo root does not fire
(`decisions/2026-09-16-if-narrows-dispatch-and-the-script-tests-the-path.md`).

**An alternation in `if` matches nothing, and says so nowhere.** Register one
handler per tool under the same matcher, both running the same script.
`Write(**/dev_docs/**)|Edit(**/dev_docs/**)` is accepted, logs no parse error,
and produced zero spawns where `Write(**/dev_docs/**)` alone produced one. The
config reads as something a later editor would tidy back into one handler,
which is why the suite fails an alternation
(`decisions/2026-09-16-two-handlers-because-if-takes-one-rule.md`).

**Register on the tools the guidance is about.** The `dev_docs/` hook takes
`Write|Edit` and not `Read`. `Read` fires far more often, in browsing that will
not produce a file, and its first call would spend the session's single pointer
(`decisions/2026-09-16-dev-docs-hook-matches-write-and-edit-not-read.md`).

**When `if` cannot express the trigger, take the bare matcher and pay the cost
inside the script.** `if` matches a command prefix, and a dangerous `gh` call can carry
`gh` after `&&`, after `;`, inside a subshell, or behind a `cd`. Those are the
forms a session reaches for right after a simple one is refused. A guard that
holds on the easy case and misses them earns a trust it does not have. Register
on bare `Bash`, then exit early in the shell on two substring `case` tests
before `python3` starts. The ceiling on the cost is one short-lived shell per
Bash call; how often python starts behind it has not been measured. This is the
second hook shape in the repo, so a new hook picks a shape rather than copying
the nearest one
(`decisions/2026-09-19-the-body-guard-takes-the-bare-bash-matcher.md`).

## Where a rule lives, and where its enforcement lives

**A convention's enforcement is built in the repo that owns the convention.**
For the conventions in this plugin, that is here. Which instrument depends on
when the rule has to fire. A check under `scripts/` serves a rule that a
finished tree can settle, which is what `prose-check.py` and
`dev-docs-layout.py` do. A `PreToolUse` handler serves one that has to catch
the work as it is written. The ticket-key prohibition is the second kind, and
two placements for it look tempting and are wrong. A guard in
`bestdan/dotfiles` reaches the two machines that repo is installed on. These
rules reach cloud containers, Codex sessions, and any machine carrying the
plugin without it. A check beside `scripts/prose-check.py` reads a finished
tree, and a repo's suite only ever sees that repo. It cannot catch a comment as
it is written, in whatever repo a session is working in. A hook has a cost of
its own: every check added here runs in consumer repos that never asked for it.
The advise-never-deny shape above bounds that cost to a missing pointer
(`decisions/2026-09-19-comment-key-check-belongs-here.md`).

**Delivery decides which file states a rule, not subject matter.** `inject.sh`
injects `portable.md` and `portable-claude.md` at `SessionStart`, on every
machine and in every cloud container. `writing_about_code.md` is read on demand,
by the two skills and by co-review. So a rule that has to be in hand mid-task
goes in `portable.md` even when its subject belongs to the register file. Code
comments are the worked case. The register half is a `Code comments` section in
`writing_about_code.md`. A comment is prose written for a reader, and the rules
that make one good are the register's rules. The operative half stays in
`portable.md`: how much comment a change carries, and the ticket-key
prohibition, plus a pointer and no reworded copy
(`decisions/2026-09-19-code-comments-are-in-scope.md`).

**Where this guidance meets a repo's own conventions, the repo wins on the work
product.** Commit format, PR title and body shape, review style, code style and
test layout go to the repo's documented convention. Rules about the session's
own environment and workflow hold regardless of what the repo says, because a
repo has no standing over them. Those are worktree isolation, the sandbox, which
CLI tools to use, and a local task runner. The rule itself is `## Precedence` in
`portable.md`, and nothing enforces it: both instruction sets land in the same
context window and the model arbitrates
(`decisions/2026-09-12-repo-wins-on-work-product.md`).

## Checks

`scripts/prose-check.py` measures every tracked markdown file against two rules
from `writing_about_code.md`. `prose-check.test.sh` runs it over the
repository, so the em-dash cap fails CI: a paragraph with three or more
em-dashes is a failure. Sentence length prints a per-file rate and never
decides the exit code. Run the script by hand to re-measure either.

The asymmetry is deliberate and worth keeping. A paragraph is flagged at three
em-dashes rather than two. One dash is an interruption and so is a matched pair,
so three is the first count that exceeds one interruption. That charitable floor
is what makes a firing a finding rather than a prompt to disable the check. The
word cap stays reported because the corpus broke it in 30% of sentences when it
was measured. A check the corpus fails teaches everyone to ignore it
(`decisions/2026-09-13-em-dash-cap-blocks-sentence-length-reports.md`).

## Gotchas

**`agy` and `devin` never read stdin.** `agy` reads the file its pointer names;
bare `devin -p` on piped stdin panics, and an inline prompt suppresses the file.
Anything that must reach every reviewer goes into `<INPUT>` before dispatch.
The mistake to avoid is taking "stdin" in a design note literally and appending
to the pipe.

**`crush` does read stdin; a `NO INPUT` from it is not a stdin bug.** A
`NO INPUT` seen once during the design review raised the question. It did not
reproduce: `crush run` v0.92.0 reads stdin when it is a pipe or a regular file
and prepends the bytes plus `"\n\n"` to the prompt (`MaybePrependStdin`,
`internal/cmd/root.go:918` at tag v0.92.0); when stdin is a TTY, a socket, or a
character device it sends the prompt alone, silently. The Bash tool's inherited
stdin is a socket, so a dispatch that drops its `cat "<INPUT>" |` prefix
delivers nothing. Diagnose with `prompt_len` in `crush --cwd "<NEUTRAL>" logs`:
pointer length alone means no pipe, pointer plus 2 means an empty pipe, a
full-sized value means the model failed. The evidence is in
`workflow-skills/skills/co-review/reviewers/crush.md`.

**A skill firing is not guaranteed, and each verb has a different backstop.**
Reviewing is backed by the co-review carrier, which reads the files directly.
Authoring is backed by the title grammar in `portable.md`'s `Git:` bullet, which
every session carries whether or not the skill fires. That makes the grammar's
home load-bearing: `skills/authoring/SKILL.md` and `authoring_pull_requests.md`
cite the `Git:` bullet and restate none of it, so moving the grammar out of
`portable.md` removes the authoring backstop and leaves both files pointing at
nothing.

**A commit on `main` is not an install.** Every carrier reads the installed
plugin: the skills through `${CLAUDE_PLUGIN_ROOT}`, co-review through the
resolver, Codex through `sync_codex.sh`. A machine stays on its old copy until
`claude plugin update agent-guidance@agent-guidance` runs, and an installed copy
older than the convention files makes the resolver report nothing to attach.
`skills/plugin-delivery` carries why a release stalls and how to tell which
commit a session loaded.

**When moving a rule out of `dotfiles`, add it here first.** The Codex carrier
and `dotfiles/agents/AGENTS.md` both route to the installed plugin, so a
deletion that lands before the plugin addition is installed leaves a gap on
every machine. Add here, install, then delete there.

## The publication line

This repo is public; `bestdan/dotfiles` is private. The two files moved from
`dotfiles` were checked before the move to name no owner, repo, machine, or
platform, and the one thing that fails that check is why the draft-versus-ready
rule for PRs is split across the two repos. The rule itself is in
`portable.md`: read the owner from the `origin` remote, apply the rule you have
for that owner, and treat an owner with no rule as an ask, never a guess. The
owner table that supplies those rules stays in `dotfiles/agents/AGENTS.md`,
because it names where the author works and which repos are kept private. The
plugin's rule works without it: every owner the table does not name falls
through to "ask", which is the safe answer.

## Why the GitHub Copilot review path was dropped

An earlier version of the design generated a delimited block into each
consumer's `.github/copilot-instructions.md`, synced by a scheduled reusable
workflow, so GitHub Copilot code review would enforce the same conventions. It
was dropped because it was the only piece that needed write access to consumer
repos, and it bought exactly one consumer. Each caller workflow needed
`permissions: contents: write, pull-requests: write` plus the repo or org
setting "Allow GitHub Actions to create and approve pull requests", which is
off by default and cannot be set from a workflow file; when that toggle is
missed the scheduled job produces no PR and no signal. On work repos both gates
are org-controlled, and a committed `copilot-instructions.md` changes how
Copilot reviews everyone's PRs in a shared repo, which is a team decision.
Dropping it also dropped the per-repo pattern map, whose only consumer was the
generator; the rule it served survives in `reviewing.md` as "check the change
against the repo's documented patterns". The research on what Copilot reads,
kept because it is the expensive part to redo, is in the design record's
"Considered and dropped" section.
