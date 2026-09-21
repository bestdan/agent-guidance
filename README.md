# agent-guidance

Portable agent preferences, injected at the start of every coding-agent
session: every repo, every machine, and cloud sessions where the agent's home
directory is not yours.

**Status: carrying real content.** The two payload files hold the real rules —
`portable.md` everything that holds under any harness, `portable-claude.md` the
rules that name Claude Code machinery. The split between them was projected
once, during the migration out of `bestdan/dotfiles`, from a one-off inventory
there that recorded per rule whether it is portable and which harnesses can act
on it. That inventory is migration scaffolding with an end date; this repo is
the standing source of truth for the rules themselves.

The plugin landed first carrying a sentinel rule per file, so that delivery to
every audience could be verified before anything worth losing moved. Both files
still declare a `GUIDANCE-SENTINEL-*` marker, now as a permanent delivery canary
rather than as a placeholder.

## What it ships

| File                           | Reaches                                 | Carries                                                                    |
| ------------------------------ | --------------------------------------- | -------------------------------------------------------------------------- |
| `portable.md`                  | every harness                           | preferences any coding agent can act on                                    |
| `portable-claude.md`           | Claude Code only                        | preferences that name Claude Code machinery                                |
| `inject.sh`                    | Claude Code and Codex `SessionStart`    | prints the hook's JSON contract for the files it is given; both by default |
| `codex/hooks.json`             | Codex CLI                               | registers `inject.sh` with `portable.md` only                              |
| `skills/plugin-delivery`       | Claude Code, on demand                  | why a release may not have reached the session reading it, and what to do  |
| `skills/authoring`             | Claude Code, at PR time                 | reads `writing_about_code.md` and `authoring_pull_requests.md`             |
| `skills/reviewing`             | Claude Code, when reviewing a change    | reads `writing_about_code.md` and `reviewing.md`                           |
| `hooks/dev-docs-context.sh`    | Claude Code, before a `dev_docs/` write | names `dev_docs_layout.md` and the directory's `README.md`, once a session |
| `hooks/gh-body-guard.sh`       | Claude Code, before every Bash call     | denies a free-text `gh` argument the shell would run a substitution inside |
| `hooks/comment-key-context.sh` | Claude Code, before a write or edit     | reports a tracker key in a code comment the write adds                     |
| `dev_docs_layout.md`           | every harness, by name                  | how a repo's `dev_docs/` is laid out: directories, naming, front matter    |
| `scripts/dev-docs-layout.py`   | any repo's check suite                  | checks a repo's `dev_docs/` against that layout; exits 1 on a violation    |

The plugin is the repository root. `hooks/hooks.json` registers `inject.sh` on
Claude Code's `SessionStart` and the three hooks above on `PreToolUse`, across
two matchers: `Write|Edit` carries the `dev_docs/` pointer and the comment-key
check, and `Bash` carries the `gh` guard. Each hook is a shell wrapper beside a
`.py` file that holds its program. The root `plugin.json` follows the
[Agent Plugins](https://agent-plugins.org) layout for harnesses that read it.

Three routes, chosen by when the guidance is needed. Preferences have to be in
context from the first turn, so they ride the always-on hook. Troubleshooting
nobody needs until a symptom appears would only be noise there, so it is a
skill the harness loads when the symptom shows up. Guidance needed at one
mechanical moment rides a `PreToolUse` hook, which the harness fires on the
event rather than offering to the model: `hooks/dev-docs-context.sh` names the
`dev_docs/` layout before the first write under that directory.
The skill mechanism that was measured and abandoned first is recorded in
`dev_docs/research/2026-09-16-paths-frontmatter-on-plugin-skills.md`. The one
cost is in [Versioning](#versioning): the payload, the skills and the hook can
skew.

## Install

Claude Code:

```
claude plugin marketplace add bestdan/agent-guidance
claude plugin install agent-guidance@agent-guidance
```

Cloud sessions install enabled plugins from account settings, so enable
`agent-guidance@agent-guidance` there as well. No local file can do that for you.

Codex CLI reads the root `plugin.json`, whose `extensions.com.openai.hooks`
points at `codex/hooks.json`. That registers the same `inject.sh` on Codex's
`SessionStart`, whose output contract matches Claude Code's, and hands it
`portable.md` alone, so Codex never sees `portable-claude.md`. The hook is
declared but not yet verified on a live Codex session; until it is, the
consuming dotfiles repo also builds `~/.codex/AGENTS.md` from `portable.md`
at shell startup, so Codex loses nothing either way.

```
codex plugin marketplace add bestdan/agent-guidance
```

## Why a hook and not a CLAUDE.md

`inject.sh` carries the reasoning in its comment block. In short: a harness
reads user preferences from its own home directory, a cloud container's home is
not yours, and a plugin's `SessionStart` hook is the one channel that reaches
those sessions on the first turn.

## Versioning

Neither manifest declares a version, on purpose. The resolved version is the
commit, so every push is an update and nothing depends on remembering to bump
a string. `inject-selftest.test.sh` fails if one comes back.

**Every push is an update, but no session picks up a new _payload_ on its own.**
A local machine sits on the old commit until `claude plugin marketplace update`
and `claude plugin update` run; a cloud environment is frozen at its last build,
because a cached setup script is skipped entirely and nothing inside a session
can move it. Both failures are silent. The payload is the part that cannot
advance by itself — the skill can, which is the skew the end of this section
describes.

So the hook appends a **provenance block** naming the copy that was loaded —
the commit for an installed copy, or "a working checkout" under `--plugin-dir`
— with the date its payload was written, and how to refresh it. That does not
make a session current; it makes a session able to say what it is running,
which is the part that was missing. It is computed at inject time rather than
written into the markdown, because a literal in the file reads identically on a
fresh copy and a year-old one and so can never signal staleness.

The block also names the **plugin root** it delivered from, which is a second
job: `portable.md`'s three `Rules` bullets send a harness with no skills to
that directory for `writing_about_code.md`, `authoring_pull_requests.md`,
`reviewing.md` and `dev_docs_layout.md`, and the block is what resolves it. `dev_docs/conventions.md`
carries which carriers resolve the root and which do not.

It is not the only route on every audience, and the README should not pretend
otherwise: a local Claude session can run `claude plugin list`, which reports
`Version: <commit>` (verified 2026-09-10). What the block adds there is that the
answer is already in context, needing no command and no idea that one should be
run. Where it is the only route is **Codex**, whose generated
`~/.codex/AGENTS.md` reads identically however old it is.

**The payload and the skill can skew, and neither one dates the other.**
Auto-update hot-loads newer skills into a running process while leaving the
registry — and so the bundled hooks — pinned to the old install
([#52218](https://github.com/anthropics/claude-code/issues/52218)). A session can
therefore be reading a current `skills/plugin-delivery` while running a stale
`portable.md`, or the reverse. The provenance block dates the payload and only
the payload; do not infer the payload's age from anything the skill says.

Why a release stalls in the first place, the upstream reports, the dead ends not
worth re-walking, and the cloud procedure are all in `skills/plugin-delivery`.

## Tests

```
scripts/run-tests.sh
```

`inject.test.sh` proves the wiring; `inject-selftest.test.sh` proves each of
those assertions fails when its wiring is broken. `skills.test.sh` does the same
job for `skills/`, where the failure is quieter still: a skill whose front matter
does not parse is skipped rather than reported, so it is simply never offered.
`skills-selftest.test.sh` is its tripwire, and it is not ceremony — two of that
suite's three assertions shipped **vacuous**, passing on the exact regressions
they named, and review caught them rather than the suite. The mutations now live
in CI so a future edit cannot quietly restore that.

`prose-check.test.sh` is the odd one out: it checks content, not wiring. It runs
`scripts/prose-check.py` over every tracked markdown file and fails on a
paragraph carrying more than one em-dash interruption, which is a rule from
`writing_about_code.md` that prose alone did not hold. The same script reports
how many sentences run over the 25-word cap, and that half never fails. Why the
two rules are treated differently is in `dev_docs/conventions.md`.

`dev-docs-layout.test.sh` checks content too. It pins each rule of
`scripts/dev-docs-layout.py` at its boundary on fixtures, then runs the checker
over this repo's own `dev_docs/`, so a file that breaks `dev_docs_layout.md`
fails CI here the way it will in any repo that wires the checker in.
