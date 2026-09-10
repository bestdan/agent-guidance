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

| File                 | Reaches                              | Carries                                                                    |
| -------------------- | ------------------------------------ | -------------------------------------------------------------------------- |
| `portable.md`        | every harness                        | preferences any coding agent can act on                                    |
| `portable-claude.md` | Claude Code only                     | preferences that name Claude Code machinery                                |
| `inject.sh`          | Claude Code and Codex `SessionStart` | prints the hook's JSON contract for the files it is given; both by default |
| `codex/hooks.json`   | Codex CLI                            | registers `inject.sh` with `portable.md` only                              |

The plugin is the repository root. `hooks/hooks.json` registers `inject.sh` on
Claude Code's `SessionStart`; the root `plugin.json` follows the
[Agent Plugins](https://agent-plugins.org) layout for harnesses that read it.

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

## Tests

```
scripts/run-tests.sh
```

`inject.test.sh` proves the wiring; `inject-selftest.test.sh` proves each of
those assertions fails when its wiring is broken.
