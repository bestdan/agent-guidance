# Run 2: control, rule files present from run 1

Same command as run 1, from the same directory, with both rule files already
on disk from run 1.

Stdout, verbatim:

```
The file `hello.canary` contains a single line: `hello`.

Tokens my instructions ask me to include in a reply:

- `ALWAYSRULE-9902`, from the always-on canary rule in `~/.claude/rules/zz-experiment/always.md`.
- `PATHRULE-7731`, from the path-scoped canary rule in `~/.claude/rules/zz-experiment/canary.md`, which activated after reading a `.canary` file.

One other token appears in my context but is not a reply instruction: `GUIDANCE-SENTINEL-SHARED`, in the agent-guidance plugin's SessionStart output. It is described there as a delivery marker for tests, not something to include in replies.

ALWAYSRULE-9902 PATHRULE-7731
```

Exit 0. The rule directory was removed after this run.
