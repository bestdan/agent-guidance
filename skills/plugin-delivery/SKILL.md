---
name: plugin-delivery
description: Explains why a release of this plugin may not have reached the session reading it, and what to do about it. Use when the guidance in context looks stale or contradicts the repository, when the user asks whether their agent-guidance is current, when a merge to bestdan/agent-guidance appears not to have taken effect, when `claude plugin update` or marketplace auto-update is not producing a newer copy, or when a cloud session is running old guidance. Also covers how to tell which commit a session actually loaded.
---

# plugin-delivery

A release of this plugin does not reach a machine on its own, and when it fails
to, nothing says so. This skill is the account of why, how to tell, and what a
person has to do by hand.

Measured 2026-09-09 and 2026-09-10 against Claude Code 2.1.267–2.1.268. It
describes a third-party harness, so re-check before trusting it rather than
taking those dates as permanent.

## The two-step model

Everything below follows from this. A release reaches a machine in two steps:

1. **Refresh the marketplace clone** under `~/.claude/plugins/marketplaces/`.
2. **Install from that clone** into `~/.claude/plugins/cache/`, updating
   `installed_plugins.json`.

Auto-update on a marketplace is documented to do both — "refreshes the
marketplace data **and** updates installed plugins to their latest versions on
disk". Only the first half happens.

Measured: three marketplaces refreshed inside one three-second pass, and neither
`agent-guidance` (a new commit waiting in its clone) nor `workflow-skills` (a new
semver waiting) was installed. `installed_plugins.json` keeps the old
`installPath`, silently.

So step 2 is manual:

```sh
claude plugin update agent-guidance@agent-guidance
```

Restart the session afterwards to load the new copy.

## Am I current?

```sh
basename "$CLAUDE_PLUGIN_ROOT"                                    # what is installed
gh api repos/bestdan/agent-guidance/commits/main --jq '.sha[:12]' # what shipped
```

`$CLAUDE_PLUGIN_ROOT`, not a repository path: this has to answer in a session
that has the plugin and no checkout of anything, which is the case that matters
most. **It is set in the contexts the plugin itself provides — its hooks, and
commands a skill declares — not in an ordinary shell.** Run that line in a plain
terminal, or through a session's generic shell tool, and it expands to nothing:
`basename ""` prints an empty line, which reads as "no answer" rather than
"wrong place to ask". An empty result means use one of the two routes below, not
that the copy is missing. On a machine that syncs `bestdan/dotfiles`,
`agents/agent-guidance-dir.sh` resolves the same directory from anywhere and
additionally honours an `AGENT_GUIDANCE_DIR` override.

`basename`, not `git log`: **the installed copy is an export, not a clone.** It
has no `.git`, so every git command against it fails. Its directory name is the
short commit — 12 characters today — which is the same fact the provenance block
relies on.

**Do not read the basename's shape as a verdict about which copy you have.** The
hook does not. `inject.sh` calls it a working checkout when the directory holds
a `.git` at all (a file or a directory — a linked worktree has the former),
matches `[0-9a-f]{7,40}` for the commit case, and calls anything else a
`version`. So a non-hex basename means an install whose directory is named
something other than a commit — **not** a `--plugin-dir` checkout. The
provenance block is the source of truth for which shape you are in, and it says
so in words rather than leaving it to be inferred from a directory name.

A local Claude session has a more direct route — `claude plugin list` reports
`Version: <commit>`. **Prefer the provenance block when the two disagree.** The
listing and `installed_plugins.json` both read the registry, which can lag what
the process actually loaded; the block is emitted by the hook that ran.

Where the block is the _only_ route is **Codex**, whose generated
`~/.codex/AGENTS.md` reads identically however old it is.

## Where each step fails

**Step 1 has a known local cause, and `bestdan/dotfiles` fixes it.**
`claude plugin marketplace add` strips `autoUpdate` from the registration it
writes, so the clone never refreshes. `agents/ensure-marketplace-autoupdate.sh`
there re-asserts the flag after every add. On a machine that does not sync those
dotfiles, check `~/.claude/plugins/known_marketplaces.json` for the flag — the
`extraKnownMarketplaces` entry in `settings.json` is not what decides it.

**Step 2 is upstream, and is not promised a fix.** Reported four times, each read
rather than matched on title:

- [#61854](https://github.com/anthropics/claude-code/issues/61854) — closed as duplicate
- [#52218](https://github.com/anthropics/claude-code/issues/52218) — closed, **not planned**
- [#43763](https://github.com/anthropics/claude-code/issues/43763) — closed, **not planned**
- [#17361](https://github.com/anthropics/claude-code/issues/17361) — **open**, and the
  clearest: "installed_plugins.json shows old gitCommitSha … even though marketplace
  is at current commit"

Two of four closed _not planned_ means a fix is not promised. Treat the manual
step as possibly permanent, and do not write "upstream will fix it" into
anything.

**Do not pad that list** with
[#44276](https://github.com/anthropics/claude-code/issues/44276) or
[#49410](https://github.com/anthropics/claude-code/issues/49410). Both were read
in full and both describe the _clone_ failing to advance — "never runs
`git pull`", "git fetch runs, but the working tree is never updated". That is
step 1 with the same smell, not step 2.

## This plugin is the worst-affected kind — and this skill is the exception

[#52218](https://github.com/anthropics/claude-code/issues/52218) reports that
auto-update hot-loads newer **skills and commands** into the running process
while leaving `installed_plugins.json` untouched, so bundled **hooks** stay
pinned to the stale `installPath`.

The payload — `portable.md` and `portable-claude.md` — reaches a session through
a `SessionStart` hook, so it gets none of that partial benefit. It genuinely runs
the old file.

**This skill is on the other side of that line, so the two can skew.** A session
can be reading a current copy of this page while running stale guidance, or the
reverse. Neither is a contradiction to resolve — check the provenance block for
what the _guidance_ is, and do not infer the payload's age from this file's
contents.

The same split is why `installed_plugins.json` is not a general answer to "what
did this session load". It is reliable for the payload here, for the same reason
the payload suffers most: the payload is carried by a hook.

## Two dead ends, so nobody re-walks them

**`FORCE_AUTOUPDATE_PLUGINS=1` is not a fix** unless auto-update is actually
disabled. `autoUpdates: false` in `~/.claude.json` looks like the culprit and
often is not: the gate is

```
autoUpdates === false && (installMethod !== "native" || autoUpdatesProtectedForNative !== true)
```

so a native install with `autoUpdatesProtectedForNative: true` is unaffected and
the env var does nothing. Read out of the 2.1.268 binary. Check those three
fields before reaching for it.

**The missing `version` field is not the blocker.** This plugin declares none, so
its commit sha stands in — an obvious-looking cause. `workflow-skills` carries an
auto-bumping semver, had `2.45.1` waiting in its refreshed clone, and stalled at
`2.45.0` in the same pass. Whatever stops one stops the other.

## Cloud

A cloud session cannot be refreshed from inside at all. The environment's setup
script runs `claude plugin marketplace add` and `claude plugin install` at
environment **build**; on a later run it logs `Setup script cached from previous
run` and is skipped entirely, so the installed copy is frozen. A mid-session
install does not register with the running agent.

**The procedure needs a human at claude.ai:** invalidate the environment's
setup-script cache, rebuild, then verify from a real cloud session. Do not infer
that it worked.

Two things not to try. Editing the setup script does not help when the script is
what is being skipped. And a `SessionStart` hook cannot bootstrap the plugin that
would carry it.

**The setup script tracks the default branch; it does not pin a version.** That
follows the repo's existing stance that the commit is the version — see
[Versioning](https://github.com/bestdan/agent-guidance#versioning) — so a rebuild
always installs current guidance and there is no pin to remember to move. The
cost is accepted deliberately: a bad guidance push reaches cloud sessions at the
next rebuild with nothing standing between. That is the same exposure every local
machine already has, and pinning would trade it for a staleness that is harder to
see, since a stale pin looks exactly like a working install.

Cheapest re-check: the one-shot routine `trig_01LGDdze7Z6xT8PjZ7sbdPYa`
("agent-guidance delivery check") — a claude.ai Routine, disabled with no
schedule, fired by hand from the Routines page. Kept rather than deleted, and the
remote-trigger API exposes no delete action anyway.
