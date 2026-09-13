# Review and authoring conventions

How the reviewing and PR-authoring conventions are stored, delivered, and
enforced, and the decisions that gave the system this shape. This is the live
description. The dated design record,
`designs/2026-09-12-review-conventions-distribution.md`, says what was decided
on 2026-09-12 and is not kept current; where the two disagree, this file wins.

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
Neither loads at session start, and neither reads the other verb's file.

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
   files by name.

`portable.md` also carries the two rules every session needs without loading a
skill: the PR title grammar in its `Git:` bullet, and `## Precedence`.

## Decisions

### Two skills rather than one

Each verb pays only for its half. A session reviewing a change loads
`writing_about_code.md` plus `reviewing.md` and never the PR-body grammar; a
session opening a PR loads the reverse. One combined skill would charge every
session the half it is not doing. The split also preserves a distinction
`dotfiles/agents/AGENTS.md` had already drawn between the two files: the prose
register "applies without being read", the PR file is "read at PR time, not at
session start".

The cost is that two triggers can each fail to fire. The backstops below are
what bound that.

### Precedence: the repo wins on its own conventions

`## Precedence` in `portable.md` splits a conflict between a repo's instructions
and the guidance the user carries:

- **Conventions about the work product** (commit format, PR title and body
  shape, review style, code style, test layout): the repo's documented
  convention wins. These rules are one developer's defaults, and a repo that
  states its own is not asking for them.
- **Rules about the session's own environment and workflow** (worktree
  isolation, the Bash sandbox, which CLI tools to use, a local task runner):
  hold regardless. A repo has no standing to say how someone else's machine
  works, and one that appears to is describing its own CI.

The split is what makes the rule safe to carry into a repo the author does not
own. "The repo wins" without it would let any `AGENTS.md` override the sandbox
and worktree rules, which are safety machinery rather than preferences.

No mechanism enforces this. Both instruction sets land in the same context
window and the model arbitrates, and the default leans the wrong way for the
first half, because a user-level file arrives flagged as overriding and a repo
file arrives as ordinary context. The section is a stated tiebreak, nothing
more.

### The co-review carrier is the assembled file, not stdin

Four of the five reviewers are cut off from repo context by mechanism: `crush`
pins `--cwd <NEUTRAL>`, `agy` trusts only its `--add-dir`, `devin` runs from a
neutral cwd, `copilot` runs in GitHub's cloud. `codex` is the partial
exception: `codex exec` runs in the repo and `~/.codex/AGENTS.md` carries
`portable.md`, though it is unverified that a co-review dispatch loads it, and
its pointer forbids exploring the filesystem in any case. The one artifact all
five receive is the assembled `<INPUT>` file, so the conventions go into that
file. Three reviewers get it piped on stdin, but `agy` opens `<INPUT>` by the
path in its pointer and `devin` takes it with `--prompt-file`; a segment wired
into the pipe reaches three of five and silently misses two.

Two more details of the shape are load-bearing:

- The paths are resolved once before dispatch and pasted into the assembling
  `cat`, never computed by a script segment inside the dispatch line. `agy`'s
  and `devin`'s assembly is chained with `&&`, where a non-zero exit would
  cancel the dispatch instead of failing soft. The reviewer command tails are
  byte-identical to before, so the exact-match allow rules still match.
- It fails soft by exit code. `agent-guidance-dir.sh` exits `3` when the plugin
  is not installed anywhere it looks (stdout empty), and
  `coreview-conventions.sh` returns the same code when the installed copy ships
  neither file; the dispatcher then drops the segment and records
  `conventions: not attached — <reason>` on the run summary's Reviewers line.
  Exit `1` (`AGENT_GUIDANCE_DIR` set but wrong) is surfaced, not swallowed.

This is the only carrier that reads the files itself rather than instructing a
model to read them, which makes it the load-bearing carrier for reviewing. Its
cost is ongoing: measured at 10,509 bytes, about 2.6k tokens, per reviewer
dispatch, so about 13k tokens across a five-reviewer run.

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
