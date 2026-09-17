# Review and authoring conventions

How the reviewing and PR-authoring conventions are stored, delivered, and
enforced. This is the live description; the choices behind it are records
under `decisions/`, listed at the end, and nothing here requires reading them.

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
   files from the plugin root.

`portable.md` also carries the two rules every session needs without loading a
skill: the PR title grammar in its `Git:` bullet, and `## Precedence`.

Another carrier shape exists and carries none of this content yet: a
`PreToolUse` hook, which the harness fires on a tool call rather than offering
to the model. `hooks/dev-docs-context.sh` is the one instance, naming
`dev_docs_layout.md` before a write under `dev_docs/`. It is the shape for
guidance whose trigger is mechanical rather than a judgment. It requires an
`if` condition in `hooks/hooks.json` per tool, and costs one process spawn per
matching call.

The hook itself reaches Claude Code only, since Codex registers `SessionStart`
alone. Codex is not left without the layout: the `Writing anything under
dev_docs/` bullet in `portable.md` names the same file, and carrier 3 above
delivers it. The hook is an upgrade on a route both harnesses have, not the
only route. The choices behind it are the `2026-09-16-` records listed below.

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

## Checks

`scripts/prose-check.py` measures every tracked markdown file against two rules
from `writing_about_code.md`. `prose-check.test.sh` runs it over the
repository, so the em-dash cap fails CI: a paragraph with three or more
em-dashes is a failure. Sentence length prints a per-file rate and never
decides the exit code. Run the script by hand to re-measure either.

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

## Decisions

The choices behind this shape are one record each under `decisions/`, in the
form `decisions/README.md` describes: context, decision, consequences, and
what would reopen it.

- `2026-09-12-two-skills-by-verb.md`: two skills split by verb rather than one
  combined conventions skill.
- `2026-09-12-repo-wins-on-work-product.md`: the repo wins on work-product
  conventions; session rules hold regardless.
- `2026-09-12-co-review-carrier-is-the-assembled-file.md`: the co-review
  carrier is the assembled input file, not a stdin segment.
- `2026-09-13-em-dash-cap-blocks-sentence-length-reports.md`: the em-dash cap
  fails CI and sentence length is reported.
- `2026-09-16-conditional-guidance-rides-a-pretooluse-hook.md`: guidance with a
  mechanical trigger rides a `PreToolUse` hook rather than a skill.
- `2026-09-16-dev-docs-hook-emits-a-pointer.md`: the hook names
  `dev_docs_layout.md` rather than inlining it.
- `2026-09-16-dev-docs-pointer-fires-once-per-session.md`: a marker keyed on the
  session id holds the pointer to one copy.
- `2026-09-16-dev-docs-hook-never-denies-the-write.md`: the hook advises and
  exits 0 on every path; the checker is the tier that says no.
- `2026-09-16-if-narrows-dispatch-and-the-script-tests-the-path.md`: `if`
  decides whether the script runs, the script decides whether it speaks.
- `2026-09-16-two-handlers-because-if-takes-one-rule.md`: two handlers on the
  matcher, because an alternation in `if` matches nothing.
- `2026-09-16-dev-docs-hook-matches-write-and-edit-not-read.md`: `Write|Edit`
  rather than `Read`.
