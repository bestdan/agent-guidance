---
created: 2026-09-22
question: "does a rule file that a SessionStart hook writes into ~/.claude/rules/ load in that same session"
feeds: ../../decisions/2026-09-16-conditional-guidance-rides-a-pretooluse-hook.md
---

# Rules written by a `SessionStart` hook: which load in the same session

## Question

Betterment's `the-book` CLI delivers path-scoped standards to Claude Code by
having a `SessionStart` hook regenerate `~/.claude/rules/the-book/` every
session. A plugin cannot ship `.claude/rules/`
(`../2026-09-16-paths-frontmatter-on-plugin-skills.md`), but a plugin hook
could write there. That only works if a rule file written during
`SessionStart` is honoured by the session that wrote it, so: is it?

## Method

Measured once on 2026-09-22 against Claude Code 2.1.280 on macOS, headless,
against the user-level `~/.claude/rules/` directory.

A throwaway project held `hello.canary` and `notes.txt`. `settings.json`,
passed to `claude -p` with `--settings`, registered `write-rule.sh` on
`SessionStart`. That script writes two files into
`~/.claude/rules/zz-experiment/`:

- `canary.md`, with `paths: ["**/*.canary"]`, instructing the model to include
  the token `PATHRULE-7731` in its reply whenever it reads a `.canary` file.
- `always.md`, with no `paths:`, instructing the model to include
  `ALWAYSRULE-9902` in every reply.

Each run asked the session to read `hello.canary` with the Read tool and then
list every token its instructions asked it to include. Run 1 started with the
rule directory absent, so the hook was the only thing that could have written
it. Run 2 was the control: the same command with both files already on disk
from run 1. The directory was removed afterwards. Both runs were unsandboxed,
because the hook writes under `~/.claude/` and the session needs the network.

Artifacts under `references/`: the hook script, the settings file with the
scratchpad path replaced by a placeholder, and both transcripts verbatim.

## Findings

### A `paths:`-scoped rule written at `SessionStart` loads in that session (verified)

Run 1's reply carried `PATHRULE-7731` and named
`~/.claude/rules/zz-experiment/canary.md` as its source, saying it "loaded only
after I read the `.canary` file". The directory did not exist before the run
and did after it, with file times matching the run's start. See
`references/run-1-transcript.md`.

### An always-on rule written at `SessionStart` does not load until the next session (verified for the effect, inferred for the cause)

Run 1's reply did not carry `ALWAYSRULE-9902` and did not mention `always.md`,
though the file was on disk by the end of the run. Run 2, with the file
pre-existing, carried both tokens and named both files
(`references/run-2-transcript.md`). The effect is measured. The cause, that
rules without `paths:` are read at startup before hooks run while `paths:`
rules are resolved at the file access that matches them, is the reading that
fits both runs and was not traced in the harness.

### The hook's stderr does not reach the captured output (verified)

`write-rule.sh` prints `wrote rules <time>` to stderr. That line was absent
from run 1's captured stderr, which held only tool-manager noise. The evidence
that the hook ran is the directory's appearance, not the log line.

### Not measured

- Whether a cloud session's `$HOME/.claude/rules/` is writable by a hook and
  honoured the same way. `inject.sh` exists because `~/.claude` is
  harness-owned there; this experiment ran on a laptop only.
- Whether a `paths:` rule fires for a `Write` that creates a matching file
  that does not yet exist. The 2026-09-16 research found a `paths:` skill
  fires after the write; `the-book` adds a `PreToolUse` hook on `Write` for
  exactly that gap, which is the same shape as this plugin's
  `hooks/dev-docs-context.sh`.
- Project-level `.claude/rules/`. The user-level directory was tested because
  it is the one `the-book` writes and the one a plugin hook could write without
  leaving files in a consumer repo.

## Feeds

`../../decisions/2026-09-16-conditional-guidance-rides-a-pretooluse-hook.md`,
whose "Revisit when" names a plugin being able to ship `.claude/rules/`. This
record shows a hook-written user-level rules directory is a working variant of
that for path-scoped content. The decision carries a dated callout pointing
here; it was not superseded, because the `PreToolUse` hook still covers the
new-file case a `paths:` rule misses, and the always-on payload cannot ride a
rules directory at all.
