---
created: 2026-09-25
question: "which parts of agent-guidance and workflow-skills would be better implemented as extensions to a minimal, programmable harness such as pi than as a Claude Code plugin"
feeds:
---

# What a programmable harness like pi would change for this plugin

## Question

pi is a minimal coding-agent harness whose features are TypeScript
extensions the user writes. Which parts of this plugin, of `workflow-skills`,
and of the Claude Code machinery in `bestdan/dotfiles` would be better built
that way, and which would get worse?

## Method

On 2026-09-25, read pi's public documentation and its author's launch post:

- [pi.dev](https://pi.dev/), the project landing page.
- The `packages/coding-agent/docs/` directory of
  [earendil-works/pi](https://github.com/earendil-works/pi), specifically
  `extensions.md`, `security.md`, `skills.md`, `packages.md` and
  `how-pi-works.md`.
- The example index at `packages/coding-agent/examples/extensions/`.
- Mario Zechner,
  [the pi coding agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/),
  2025-11-30.

pi was not installed or run. Every claim about pi's behaviour below comes
from those documents, not from a session.

This side of the comparison was read from the repositories on the same date:

- this repo's `hooks/hooks.json`, `inject.sh` and `README.md`;
- `workflow-skills`' `hooks/hooks.json` and `skills/`;
- the hook scripts under `bestdan/dotfiles` `agents/`, and `CLAUDE_ONLY.md`
  and `RTK.md` there.

## Findings

### pi is a small core with hook points for everything else (documented)

The launch post gives a system prompt under 1,000 tokens and four tools:
read, write, edit and bash. It has no MCP, plan mode, subagents, permission
prompts or background bash. The landing page states the design line as
"primitives, not features."

Extensions are TypeScript modules loaded into the pi process. `extensions.md`
lists the events they subscribe to, among them:

- `before_agent_start`, which can modify the system prompt;
- `tool_call`, which can mutate a tool's input or block it;
- `tool_result`, which can change what a tool returns;
- `context`, which can rewrite the message history before a request.

Extensions can also register tools and slash commands. The example index
includes `tool-override.ts`, described as overriding built-in tools, and
examples for subagents, plan mode, a permission gate, protected paths and a
sandbox. The sandbox example is described as "OS-level sandboxing using
`@anthropic-ai/sandbox-runtime`", the same library that backs Claude Code's.

### pi reads the content formats this plugin already writes (documented)

`skills.md` says pi implements the Agent Skills specification. It discovers
skills from `~/.agents/skills/` and `.agents/skills/` among other places, and
lists each skill's name and description in the system prompt until the skill
is invoked. Context comes from `AGENTS.md` files in `~/.pi/agent/`, parent
directories and the working directory.

`skills.md` does not mention `~/.claude/skills`. So a skill shipped only
through this plugin's Claude Code install is not discovered. Reaching pi
would take a second install location, not a rewrite.

### Packages pin to a ref and update only on command (documented)

`packages.md` says a package installs from npm, git or a local path. A git
source pins to a tag or commit, and `pi update` reconciles checkouts without
moving the configured ref. Project-scope packages load only after the user
trusts the project.

This differs from the failure this repo's `README.md` describes under
"Versioning". There, auto-update hot-loads new skills into a running process
while the hooks stay on the old install
([anthropics/claude-code#52218](https://github.com/anthropics/claude-code/issues/52218)).
The docs describe nothing in pi that updates part of a package. Whether a pi
session can report which ref it loaded was not checked.

### pi has no permission layer and no cloud sessions (documented)

`security.md` says pi runs with the permissions of the account that starts it
and does not ask before executing a tool call. It recommends a container or
VM for isolation. Project trust gates `.pi/` extensions, skills and settings,
but `AGENTS.md` loads regardless of trust.

None of the documents read describe a hosted or cloud session. `inject.sh`'s
comment block gives cloud containers as the reason this plugin delivers
through a `SessionStart` hook rather than a home-directory file.

### How each piece of this stack maps onto pi (inferred)

These are inferences from the documented hook points, not from building
anything.

| Piece                                                                                                                                     | Its mechanism here                                                                    | The pi equivalent                                                                   |
| ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `portable.md` and the other rule files                                                                                                    | Injected by `inject.sh` on `SessionStart`                                             | A static `~/.pi/agent/AGENTS.md`, or a `before_agent_start` append                  |
| Skills in both repos                                                                                                                      | Claude Code plugin skills                                                             | Agent Skills from `~/.agents/skills/`, with no change to the file format            |
| `hooks/prose-context.sh`, `hooks/dev-docs-context.sh`                                                                                     | `PreToolUse` on Write and Edit, adding the rule to context                            | `tool_call` for the same, and `tool_result` could return `prose-check.py`'s output  |
| `hooks/gh-body-guard.sh`                                                                                                                  | `PreToolUse` on Bash, pattern-matching a `gh` command for shell substitution          | A registered tool taking the PR body as a structured field, so no shell text exists |
| The worktree isolation guard, the `rtk` permission twins, the `WorktreeCreate` hook, the sandbox `$TMPDIR` split, auto-mode batch denials | Workarounds for Claude Code's own guards, documented in `CLAUDE_ONLY.md` and `RTK.md` | None needed, since pi has none of those guards. Nor any of their protection         |
| `auto-pilot`, `deliver-task`, `orchestrate-coders`                                                                                        | Skills that drive the Agent tool and spawn a detached orchestrator                    | A program on pi's SDK or RPC mode, or equally on the Claude Agent SDK               |
| Subagents, `isolation: worktree`, Workflow, auto mode, remote control                                                                     | Built into Claude Code                                                                | Extensions or third-party packages, or nothing                                      |

Two rows cut in opposite directions. The `gh-body-guard` row would remove
the problem rather than guard against it. The Claude Code guards row would drop both the
friction and the protection that caused it, so a pi setup would rebuild a
sandbox and permission gate from the examples.

### The cost pi's author states (documented)

The launch post lists what pi lacked at the time: compaction, tool-result
streaming, and built-in read-only restrictions. It also notes that pi
assumes full filesystem access and needs tmux for background processes.
`compaction.md` exists in the current docs, so the first of those has since
changed; the others were not rechecked.

## Feeds

No design or decision cites this yet.
